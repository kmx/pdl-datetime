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
use PDL::Core  qw(longlong long double byte short);
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

  # for 'PDL::DateTime' just make a copy                                #XXX-FIXME is copy() what we want?
  return $data->copy(%opts) if ref $data eq 'PDL::DateTime';

  my $self = $class->initialize(%opts);
  # $data is expected to contain epoch timestamps in microseconds
  if (ref $data eq 'ARRAY') {
    $self->{PDL} = longlong($data);
  }
  elsif (ref $data eq 'PDL') {
    if ($data->type == longlong) {
      $self->{PDL} = $data->copy;                                       #XXX-FIXME is copy() what we want?
    }
    elsif ($data->type == double) {
      $self->{PDL} = longlong(floor($data + 0.5));
      $self->{PDL} -= $self->{PDL} % 1000; #truncate to milliseconds
    }
    else {
      $self->{PDL} = longlong($data);
    }
  }
  else {
    die "new: invalid param ref='".ref($data)."'";
  }

  return $self;
}

# Derived objects need to supply its own copy!
sub copy {
  my ($self, %opts) = @_;
  my $new = $self->initialize(%opts);
  # copy the PDL
  $new->{PDL} = $self->{PDL}->SUPER::copy;
  # copy the other stuff
  #$new->{someThingElse} = $self->{someThingElse};
  return $new;
}

sub new_from_epoch {
  my ($class, $ep, %opts) = @_;
  my $self = $class->initialize(%opts);
  $ep = double($ep) if ref $ep eq 'ARRAY';
  # convert epoch timestamp in seconds to microseconds
  $self->{PDL} = longlong(floor(double($ep) * 1_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_ratadie {
  my ($class, $rd, %opts) = @_;
  my $self = $class->initialize(%opts);
  $rd = double($rd) if ref $rd eq 'ARRAY';
  # EPOCH = (RD - 719_163) * 86_400
  # only milisecond precision => strip microseconds
  $self->{PDL} = longlong(floor((double($rd) - 719_163) * 86_400_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_serialdate {
  my ($class, $sd, %opts) = @_;
  my $self = $class->initialize(%opts);
  $sd = double($sd) if ref $sd eq 'ARRAY';
  # EPOCH = (SD - 719_163 - 366) * 86_400
  # only milisecond precision => strip microseconds
  $self->{PDL} = longlong(floor((double($sd) - 719_529) * 86_400_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_juliandate {
  my ($class, $jd, %opts) = @_;
  my $self = $class->initialize(%opts);
  $jd = double($jd) if ref $jd eq 'ARRAY';
  # EPOCH = (JD - 2_440_587.5) * 86_400
  # only milisecond precision => strip microseconds
  $self->{PDL} = longlong(floor((double($jd) - 2_440_587.5) * 86_400_000 + 0.5)) * 1000;
  return $self;
}

sub new_from_datetime {
  my ($class, $array, %opts) = @_;
  my $self = $class->initialize(%opts);
  $self->{PDL} = longlong _datetime_to_jumboepoch($array);
  return $self;
}

sub new_from_parts {
  my ($class, $y, $m, $d, $H, $M, $S, $U, %opts) = @_;
  die "new_from_parts: args - y, m, d - are mandatory" unless defined $y && defined $m && defined $d;
  my $self = $class->initialize(%opts);
  $y = long($y) if ref $y eq 'ARRAY';
  $d = long($d) if ref $d eq 'ARRAY';
  $m = long($m) if ref $m eq 'ARRAY';
  $H = long($H) if ref $H eq 'ARRAY';
  $M = long($M) if ref $M eq 'ARRAY';
  $S = long($S) if ref $S eq 'ARRAY';
  $U = long($U) if ref $U eq 'ARRAY';
  my $rdate = _ymd2ratadie($y->copy, $m->copy, $d->copy);
  my $epoch = (floor($rdate) - 719163) * 86400;
  $epoch += floor($H) * 3600 if defined $H;
  $epoch += floor($M) * 60   if defined $M;
  $epoch += floor($S)        if defined $S;
  $epoch = longlong($epoch) * 1_000_000;
  $epoch += longlong(floor($U)) if defined $U;
  $self->{PDL} = longlong($epoch);
  return $self;
}

sub new_from_ymd {
  my ($class, $ymd) = @_;
  my $y = floor(($ymd/10000) % 10000);
  my $m = floor(($ymd/100) % 100);
  my $d = floor($ymd % 100);
  return $class->new_from_parts($y, $m, $d);
}

sub new_sequence {
  my ($class, $start, $count, $unit, $step, %opts) = @_;
  die "new_sequence: args - count, unit - are mandatory" unless defined $count && defined $unit;
  $step = 1 unless defined $step;
  my $self = $class->initialize(%opts);
  my $dt = _fix_datetime_value($start);
  my $tm_start = $dt eq 'now' ? Time::Moment->now_utc : Time::Moment->from_string($dt, lenient=>1);
  my $microseconds = $tm_start->microsecond;
  if ($unit eq 'year') {
    # slow :(
    my @epoch = ($tm_start->epoch);
    push @epoch, $tm_start->plus_years($_*$step)->epoch for (1..$count-1);
    $self->{PDL} = longlong(\@epoch) * 1_000_000 + $microseconds;
  }
  if ($unit eq 'month') {
    # slow :(
    my @epoch = ($tm_start->epoch);
    push @epoch, $tm_start->plus_months($_*$step)->epoch for (1..$count-1);
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
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in milliseconds!
  return double($epoch_milisec) / 1_000;
}

sub longlong_epoch {
  my $self = shift;
  # EP = JUMBOEPOCH / 1_000_000;
  # BEWARE: precision only in seconds!
  my $epoch_sec = ($self - ($self % 1_000_000)) / 1_000_000;
  #return longlong($epoch_sec); # XXX-FIXME this returns still PDL::DateTime;
  return longlong($epoch_sec->{PDL});
}

sub double_ratadie {
  my $self = shift;
  # RD = EPOCH / 86_400 + 719_163;
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in milliseconds!
  return double($epoch_milisec) / 86_400_000 + 719_163;
}

sub double_serialdate {
  my $self = shift;
  # SD = EPOCH / 86_400 + 719_163 + 366;
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in milliseconds!
  return double($epoch_milisec) / 86_400_000 + 719_529;
}

sub double_juliandate {
  my $self = shift;
  # JD = EPOCH / 86_400 + 2_440_587.5;
  my $epoch_milisec = ($self - ($self % 1000)) / 1000; # BEWARE: precision only in milliseconds!
  return double($epoch_milisec) / 86_400_000 + 2_440_587.5;
}

sub dt_ymd {
  my $self = shift;
  my $rdate = $self->double_ratadie;
  my ($y, $m, $d) = _ratadie2ymd($rdate);
  return (short($y), byte($m), byte($d));
}

sub dt_hour {
  my $self = shift;
  return PDL->new(byte((($self - ($self % 3_600_000_000)) / 3_600_000_000) % 24));
}

sub dt_minute {
  my $self = shift;
  return PDL->new(byte((($self - ($self % 60_000_000)) / 60_000_000) % 60));
}

sub dt_second {
  my $self = shift;
  return PDL->new(byte((($self - ($self % 1_000_000)) / 1_000_000) % 60));
}

sub dt_microsecond {
  my $self = shift;
  return PDL->new(long($self % 1_000_000));
}

sub dt_day_of_week {
  my $self = shift;
  my $days = ($self - ($self % 86_400_000_000)) / 86_400_000_000;
  return PDL->new(byte(($days + 3) % 7) + 1); # 1..Mon, 7..Sun
}

sub dt_day_of_year {
  my $self = shift;
  my $rd1 = long(floor($self->double_ratadie));
  my $rd2 = long(floor($self->dt_truncate('year')->double_ratadie));
  return PDL->new(short, ($rd1 - $rd2 + 1));
}

sub dt_add {
  my $self = shift;
  if ($self->is_inplace) {
    $self->set_inplace(0);
    while (@_) {
      my ($unit, $num) = (shift, shift);
      if ($unit eq 'month') {
        $self += $self->_plus_delta_m($num);
      }
      elsif ($unit eq 'year') {
        $self += $self->_plus_delta_m($num * 12);
      }
      elsif ($unit eq 'millisecond') {
        $self += $num * 1000;
      }
      elsif ($unit eq 'microsecond') {
        $self += $num;
      }
      elsif (my $inc = $INC_SECONDS{$unit}) {
        my $add = longlong(floor($num * $inc * 1_000_000 + 0.5));
        $self->inplace->plus($add, 0);
      }
    }
    return $self;
  }
  else {
    my $rv = $self->copy;
    while (@_) {
      my ($unit, $num) = (shift, shift);
      if ($unit eq 'month') {
        $rv += $rv->_plus_delta_m($num);
      }
      elsif ($unit eq 'year') {
        $rv += $rv->_plus_delta_m($num * 12);
      }
      elsif ($unit eq 'millisecond') {
        $rv += $num * 1000;
      }
      elsif ($unit eq 'microsecond') {
        $rv += $num;
      }
      elsif(my $inc = $INC_SECONDS{$unit}) {
        $rv += longlong(floor($num * $inc * 1_000_000 + 0.5));
      }
    }
    return $rv;
  }
}

sub dt_truncate {
  my ($self, $unit) = @_;
  if ($self->is_inplace) {
    $self->set_inplace(0);
    return $self unless defined $unit;
    if ($unit eq 'year') {
      $self->{PDL} = $self->_allign_m_y(0, 1)->{PDL};
    }
    elsif ($unit eq 'month') {
      $self->{PDL} = $self->_allign_m_y(1, 0)->{PDL};
    }
    elsif ($unit eq 'millisecond') {
      my $sub = $self % 1_000;
      $self->inplace->minus($sub, 0);
    }
    elsif (my $inc = $INC_SECONDS{$unit}) {
      my $sub = $self % ($inc * 1_000_000);
      $self->inplace->minus($sub, 0);
    }
    return $self;
  }
  else {
    return unless defined $unit;
    if ($unit eq 'month') {
      return $self->_allign_m_y(1, 0);
    }
    elsif ($unit eq 'year') {
      return $self->_allign_m_y(0, 1);
    }
    elsif ($unit eq 'millisecond') {
      return $self - $self % 1_000;
    }
    elsif (my $inc = $INC_SECONDS{$unit}) {
      return $self - $self % ($inc * 1_000_000);
    }
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
  PDL::Core::set_c($self, [@_], _datetime_to_jumboepoch($datetime));
}

sub dt_unpdl {
  my ($self, $fmt) = @_;
  $fmt = $self->_autodetect_strftime_format if !$fmt || $fmt eq 'auto';
  if ($fmt eq 'epoch') {
    return (double($self) / 1_000_000)->unpdl;
  }
  elsif ($fmt eq 'epoch_int') {
    return longlong(($self - ($self % 1_000_000)) / 1_000_000)->unpdl;
  }
  else {
    my $array = $self->unpdl;
    _jumboepoch_to_datetime($array, $fmt, 1); # change $array inplace!
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

sub _plus_delta_m {
  my ($self, $delta_m) = @_;
  my $day_fraction = $self % 86_400_000_000;
  my $rdate_bf = ($self - $day_fraction)->double_ratadie;
  my ($y, $m, $d) = _ratadie2ymd($rdate_bf);
  my $rdate_af = _ymd2ratadie($y, $m, $d, $delta_m);
  my $rv = longlong($rdate_af - $rdate_bf) * 86_400_000_000;
  return $rv;
}

sub _allign_m_y {
  my ($self, $mflag, $yflag) = @_;
  my $rdate = $self->double_ratadie;
  my ($y, $m, $d) = _ratadie2ymd($rdate);
  $d .= 1 if $mflag || $yflag;
  $m .= 1 if $yflag;
  $rdate = _ymd2ratadie($y, $m, $d);
  return PDL::DateTime->new(longlong(floor($rdate) - 719163) * 86_400_000_000);
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
  my ($dt, $inplace) = @_;
  my $tm;
  if (ref $dt eq 'ARRAY') {
    my @new;
    for (@$dt) {
      my $s = _datetime_to_jumboepoch($_, $inplace);
      if ($inplace) {
        $_ = ref $_ ? undef : $s;
      }
      else {
        push @new, $s;
      }
    }
    return \@new if !$inplace;
  }
  else {
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
    my $ep = $tm->epoch;
    my $us = $tm->microsecond;
    return int($ep * 1_000_000 + $us);
  }
}

sub _jumboepoch_to_datetime {
  my ($v, $fmt, $inplace) = @_;
  return 'BAD' unless defined $v;
  if (ref $v eq 'ARRAY') {
    my @new;
    for (@$v) {
      my $s = _jumboepoch_to_datetime($_, $fmt, $inplace);
      if ($inplace) {
        $_ = $s;
      }
      else {
        push @new, $s;
      }
    }
    return \@new if !$inplace;
  }
  elsif (!ref $v) {
    my $us = int($v % 1_000_000);
    my $ts = int(($v - $us) / 1_000_000);
    my $tm = eval { Time::Moment->from_epoch($ts, $us * 1000) };
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
  my ($y, $m, $d, $delta_m) = @_;
  # based on Rata Die calculation from https://metacpan.org/source/DROLSKY/DateTime-1.10/lib/DateTime.xs#L151
  # RD: 1       => 0001-01-01
  # RD: 2       => 0001-01-02
  # RD: 719163  => 1970-01-01
  # RD: 730120  => 2000-01-01
  # RD: 2434498 => 6666-06-06
  # RD: 3652059 => 9999-12-31

  if (defined $delta_m) {
    # handle months + years
    $m->inplace->plus($delta_m - 1, 0);
    my $extra_y = floor($m / 12);
    $m->inplace->modulo(12, 0);
    $m->inplace->plus(1, 0);
    $y->inplace->plus($extra_y, 0);
    # fix days
    my $dec_by_one = ($d==31) * (($m==4) + ($m==6) + ($m==9) + ($m==11));
    # 1800, 1900, 2100, 2200, 2300 - common; 2000, 2400 - leap
    my $is_nonleap_yr = (($y % 4)!=0) + (($y % 100)==0) - (($y % 400)==0);
    my $dec_nonleap_feb = ($m==2) * ($d>28) * $is_nonleap_yr * ($d-28);
    my $dec_leap_feb    = ($m==2) * ($d>29) * (1 - $is_nonleap_yr) * ($d-29);
    $d->inplace->minus($dec_by_one + $dec_leap_feb + $dec_nonleap_feb, 0);
  }

  my $rdate = double($d); # may contain day fractions
  $rdate->setbadif(($y < 1) + ($y > 9999));
  $rdate->setbadif(($m < 1) + ($m > 12));
  $rdate->setbadif(($d < 1) + ($d >= 32));  # not 100% correct (max. can be 31.9999999)

  my $m2 = ($m <= 2);
  $y -= $m2;
  $m += $m2 * 12;

  $rdate += floor(($m * 367 - 1094) / 12);
  $rdate += floor($y % 100 * $DAYS_PER_4_YEARS / 4);
  $rdate += floor($y / 100) * $DAYS_PER_100_YEARS + floor($y / 400);
  $rdate -= $MAR_1_TO_DEC_31;
  return $rdate;
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