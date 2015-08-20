package PDL::DateTime;

use strict;
use warnings;
use parent 'PDL';

our $VERSION = '0.000_01';

use Scalar::Util 'looks_like_number';
use POSIX ();
use PDL::Types;
use PDL::Primitive;
use PDL::Basic qw(sequence);
use PDL::Math  qw(floor);
use PDL::Core  qw(longlong long double);
use Time::Moment;

use overload '""' => \&_stringify;

my %INC_SECONDS = (
  week   => 60 * 60 * 24 * 7,
  day    => 60 * 60 * 24,
  hour   => 60 * 60,
  minute => 60,
  second => 1,
);

sub initialize {
  my ($class, %args) = @_;
  $class = ref $class ? ref $class : $class;
  return bless { %args, PDL => PDL->null }, $class;
}

sub new {
  my ($class, $data, %opts) = @_;
  my $self = $class->initialize(%opts);
  # $data is expected to contain epoch timestamps in microseconds
  if (ref $data eq 'PDL' && ($data->type == longlong || $data->type == long)) {
    $self->{PDL} = longlong($data);
  }
  else {
    $self->{PDL} = longlong(floor(double($data) + 0.5));
  }
  return $self;
}

sub new_from_epoch {
  my ($class, $ep, %opts) = @_;
  my $self = $class->initialize(%opts);
  # convert epoch timestamp in seconds to microseconds
  $self->{PDL} = longlong(floor(double($ep) * 1_000_000 + 0.5));
  return $self;
}

sub new_from_ratadie {
  my ($class, $rd, %opts) = @_;
  my $self = $class->initialize(%opts);
  # EPOCH = (RD - 719_163) * 86_400
  # only milisecond precision => strip microseconds
  $self->{PDL} = longlong(floor((double($rd) - 719_163) * 86_400_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_serialdate {
  my ($class, $sd, %opts) = @_;
  my $self = $class->initialize(%opts);
  # EPOCH = (SD - 719_163 - 366) * 86_400
  # only milisecond precision => strip microseconds
  $self->{PDL} = longlong(floor((double($sd) - 719_529) * 86_400_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_juliandate {
  my ($class, $jd, %opts) = @_;
  my $self = $class->initialize(%opts);
  # EPOCH = (JD - 2_440_587.5) * 86_400
  # only milisecond precision => strip microseconds
  $self->{PDL} = longlong(floor((double($jd) - 2_440_587.5) * 86_400_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_parts {
  my ($class, $y, $m, $d, $H, $M, $S, $U, %opts) = @_;
  die "new_from_parts: args - y, m, d - are mandatory" unless defined $y && defined $m && defined $d;
  my $self = $class->initialize(%opts);
  my $rdate = _ymd2ratadie($y, $m, $d);
  my $epoch = (floor($rdate) - 719163) * 86400;
  $epoch += floor($H) * 3600 if defined $H;
  $epoch += floor($M) * 60   if defined $M;
  $epoch += floor($S)        if defined $S;
  $epoch = $epoch * 1_000_000;
  $epoch += floor($U)        if defined $U;
  $self->{PDL} = longlong($epoch);
  return $self;
}

sub new_sequence {
  my ($class, $start, $count, $unit, $step, %opts) = @_;
  die "new_sequence: args - count, unit - are mandatory" unless defined $count && defined $unit;
  $step = 1 unless defined $step;
  my $self = $class->initialize(%opts);
  my $dt = _fix_datetime_value($start);
  my $tm_start = $dt eq 'now' ? Time::Moment->now_utc : Time::Moment->from_string($dt, lenient=>1);
  my $microseconds = $tm_start->microsecond;
  if ($unit eq 'year' || $unit eq 'month') {
    # slow :(
    my @epoch = ($tm_start->epoch);
    push @epoch, $tm_start->plus_years($_*$step)->epoch for (1..$count-1);
    $self->{PDL} = longlong(\@epoch) * 1_000_000 + $microseconds;
  }
  elsif (my $inc = $INC_SECONDS{$unit}) {
    my $epoch = $tm_start->epoch;
    $self->{PDL} = (longlong(floor(sequence($count) * $step * $inc + 0.5)) + $epoch) * 1_000_000 + $microseconds;
  }
  return $self;
}

sub double_epoch {
  my $self = shift;
  # EP = JUMBOEPOCH / 1_000_000;
  return double($self) / 1_000_000;
}

sub double_ratadie {
  my $self = shift;
  # RD = EPOCH / 86_400 + 719_163;
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in miliseconds!
  return double($epoch_milisec) / 86_400_000 + 719_163;
}

sub double_serialdate {
  my $self = shift;
  # SD = EPOCH / 86_400 + 719_163 + 366;
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in miliseconds!
  return double($epoch_milisec) / 86_400_000 + 719_529;
}

sub double_juliandate {
  my $self = shift;
  # JD = EPOCH / 86_400 + 2_440_587.5;
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in miliseconds!
  return double($epoch_milisec) / 86_400_000 + 2_440_587.5;
}

sub dt_ymd {
  my $self = shift;
  my $rdate = $self->double_ratadie;
  my ($y, $m, $d) = _ratadie2ymd($rdate);
  return (long($y), long($m), long($d));
}

sub dt_hours {
  my $self = shift;
  return PDL->new(long((($self - ($self % 3_600_000_000)) / 3_600_000_000) % 24));
}

sub dt_minutes {
  my $self = shift;
  return PDL->new(long((($self - ($self % 60_000_000)) / 60_000_000) % 60));
}

sub dt_seconds {
  my $self = shift;
  return PDL->new(long((($self - ($self % 1_000_000)) / 1_000_000) % 60));
}

sub dt_microseconds {
  my $self = shift;
  return PDL->new(long($self % 1_000_000));
}

sub dt_weekdays {
  my $self = shift;
  my $days = ($self - ($self % 86_400_000_000)) / 86_400_000_000;
  return PDL->new(long(($days + 3) % 7)); # +3 ... 0=Mon, +4 ... 0=Sun
}

sub dt_add {
  my ($self, $num, $unit) = @_;
  # XXX-TODO missing support for 'month' and 'year'
  die "dt_add: missing argument" if !defined $num || !$unit;
  my $inc = $INC_SECONDS{$unit};
  die "dt_add: invalid unit '$unit'" if !$inc;
  if ($self->is_inplace) {
    $self->set_inplace(0);
    my $add = longlong(floor($num * $inc * 1_000_000 + 0.5));
    $self->inplace->plus($add, 0);
    return $self;
  }
  else {
    return $self + longlong(floor($num * $inc * 1_000_000 + 0.5));
  }
}

sub dt_align {
  my ($self, $unit) = @_;
  # XXX-TODO missing support for 'month' and 'year'
  die "dt_align: missing unit" if !$unit;
  my $inc = $INC_SECONDS{$unit};
  die "dt_align: invalid unit '$unit'" if !$inc;
  if ($self->is_inplace) {
    $self->set_inplace(0);
    my $sub = $self % ($inc * 1_000_000);
    $self->inplace->minus($sub, 0);
    return $self;
  }
  else {
    return $self - $self % ($inc * 1_000_000);
  }
}

sub dt_at {
  my $self = shift;
  my $fmt = looks_like_number($_[-1]) ? 'auto' : pop;
  my $v = PDL::Core::at_c($self, [@_]);
  $fmt = $self->_autodetect_strftime_format if !$fmt || $fmt eq 'auto';
  return _jumboepoch_to_datetime($v, $fmt);
}

sub dt_set {
  my $self = shift;
  my $datetime = pop;
  my $v = _datetime_to_jumboepoch($datetime);
  PDL::Core::set_c($self, [@_], $v);
}

sub dt_unpdl {
  my ($self, $fmt) = @_;
  $fmt = $self->_autodetect_strftime_format if !$fmt || $fmt eq 'auto';
  if ($fmt eq 'epoch') {
    return (double($self) / 1_000_000)->unpdl;
  }
  elsif ($fmt eq 'epoch_int') {
    return (longlong(floor(double($self) / 1_000_000)))->unpdl;
  }
  else {
    my $array = $self->unpdl;
    _jumboepoch_to_datetime($array, $fmt); # recursive/inplace!
    return $array;
  }
}

### private methods

sub _stringify {
  my $self = shift;
  my $data = $self->dt_unpdl;
  return _print_array($data, 0);
}

sub _autodetect_strftime_format {
  my $self = shift;
  if (which(($self % (24*60*60*1_000_000)) != 0)->nelem == 0) {
    return "%Y-%m-%d";
  }
  elsif (which(($self % (60*1_000_000)) != 0)->nelem == 0) {
    return "%Y-%m-%dT%H:%M";
  }
  elsif (which(($self % 1_000_000) != 0)->nelem == 0) {
    return "%Y-%m-%dT%H:%M:%S";
  }
  elsif (which(($self % 1_000) != 0)->nelem == 0) {
    return "%Y-%m-%dT%H:%M:%S.%3N";
  }
  else {
    return "%Y-%m-%dT%H:%M:%S.%6N";
  }
}

### private functions

sub _print_array {
  my ($val, $level) = @_;
  my $prefix = " " x $level;
  if (ref $val eq 'ARRAY' && !ref $val->[0]) {
    return $prefix . join(" ", '[', @$val, ']') . "\n";
  }
  elsif (ref $val eq 'ARRAY') {
    my $out = $prefix."[\n";
    $out .= _print_array($_, $level + 1) for (@$val);
    $out .= $prefix."]\n";
  }
  else {
    return $prefix . $val . "\n";
  }
}

sub _fix_datetime_value {
  my $v = shift;
  # '2015-12-29' > '2015-12-29T00Z'
  return $v."T00Z" if $v =~ /^\d\d\d\d-\d\d-\d\d$/;
  # '2015-12-29 11:59' > '2015-12-29 11:59Z'
  return $v."Z"    if $v =~ /^\d\d\d\d-\d\d-\d\d[ T]\d\d:\d\d$/;
  # '2015-12-29 11:59:11' > '2015-12-29 11:59:11Z' or '2015-12-29 11:59:11.123' > '2015-12-29 11:59:11.123Z'
  return $v."Z"    if $v =~ /^\d\d\d\d-\d\d-\d\d[ T]\d\d:\d\d:\d\d(\.\d+)?$/;
  return $v;
}

sub _datetime_to_jumboepoch {
  my $dt = shift;
  my $tm;
  if (looks_like_number $dt) {
    return int POSIX::floor($dt * 1_000_000 + 0.5);
  }
  elsif (!ref $dt) {
    $dt = _fix_datetime_value($dt);
    $tm = eval { Time::Moment->from_string($dt, lenient=>1) };
  }
  elsif (ref $dt eq 'DateTime' || ref $dt eq 'Time::Piece') {
    $tm = eval { Time::Moment->from_object($dt) };
  }
  elsif (ref $dt eq 'Time::Moment') {
    $tm = $dt;
  }
  return undef unless $tm;
  return int($tm->epoch * 1_000_000 + $tm->microsecond);
}

sub _jumboepoch_to_datetime {
  my ($v, $fmt) = @_;
  return 'BAD' unless defined $v;
  if (ref $v eq 'ARRAY') { # recursive/inplace!
    for (@$v) {
      my $s = _jumboepoch_to_datetime($_, $fmt);
      $_ = $s if !ref $_;
    }
  }
  elsif (!ref $v) {
    my $ns = ($v % 1_000_000) * 1_000;
    my $ts = POSIX::floor($v / 1_000_000);
    my $tm = eval { Time::Moment->from_epoch($ts, $ns) };
    return 'BAD' unless defined $tm;
    if ($fmt eq 'Time::Moment') {
      return $tm;
    }
    else {
      return $tm->strftime($fmt);
    }
  }
}

my $DAYS_PER_400_YEARS  = 146_097;
my $DAYS_PER_100_YEARS  =  36_524;
my $DAYS_PER_4_YEARS    =   1_461;
my $MAR_1_TO_DEC_31     =     306;

sub _ymd2ratadie {
  my ($y, $m, $d) = @_;
  # based on Rata Die calculation from https://metacpan.org/source/DROLSKY/DateTime-1.10/lib/DateTime.xs#L151
  # RD: 1       => 0001-01-01
  # RD: 2       => 0001-01-01
  # RD: 719163  => 1970-01-01
  # RD: 730120  => 2000-01-01
  # RD: 2434498 => 6666-06-06
  # RD: 3652059 => 9999-12-31

  my $rdate = $d; # may contain day fractions
  $rdate = $rdate->setbadif(($y < 1) + ($y > 9999));
  $rdate = $rdate->setbadif(($m < 1) + ($m > 12));
  $rdate = $rdate->setbadif(($d < 1) + ($d >= 32));  # not 100% correct (max. can be 31.9999999)

  my $m2 = ($m <= 2);
  $y -= $m2;
  $m += $m2 * 12;

  $rdate += floor(($m * 367 - 1094) / 12);
  $rdate += floor($y % 100 * $DAYS_PER_4_YEARS / 4);
  $rdate += floor($y / 100) * $DAYS_PER_100_YEARS + floor($y / 400);
  $rdate -= $MAR_1_TO_DEC_31;
  return $rdate; # double or longlong
}

sub _ratadie2ymd {
  # based on Rata Die calculation from  https://metacpan.org/source/DROLSKY/DateTime-1.10/lib/DateTime.xs#L82
  my $rdate = shift;

  my $d = floor($rdate);
  $d += $MAR_1_TO_DEC_31;

  my $c = floor((($d * 4) - 1) / $DAYS_PER_400_YEARS); # century
  $d   -= floor($c * $DAYS_PER_400_YEARS / 4);
  my $y = floor((($d * 4) - 1) / $DAYS_PER_4_YEARS);
  $d   -= floor($y * $DAYS_PER_4_YEARS / 4);
  my $m = floor((($d * 12) + 1093) / 367);
  $d   -= floor((($m * 367) - 1094) / 12);
  $y   += ($c * 100);

  my $m12 = ($m > 12);
  $y += $m12;
  $m -= $m12 * 12;

  return ($y, $m, $d);
}

1;