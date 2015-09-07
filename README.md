# NAME

PDL::DateTime - piddle for keeping high precision (microsecond) timestamps

# DESCRIPTION

[PDL::DateTime](https://metacpan.org/pod/PDL::DateTime) is a subclass of [PDL](https://metacpan.org/pod/PDL) piddle:

- its PDL type is always `LongLong` (64-bit signed integer)
- **stored values are microseconds** since `1970-01-01T00:00:00.000000Z` (can be both positive or negative)
- it is still a piddle so you can do all usual PDL arithmetic + [PDL::DateTime](https://metacpan.org/pod/PDL::DateTime) defines some new methods (see below)

# LIMITATIONS

- supported datetimes are from `0001-01-01T00:00:00.000000Z` (epoch microseconds: `-62135596800000000`) to `9999-12-31T23:59:59.999999Z` (epoch microseconds: `253402300799999999`)
- leap seconds are completely ignored
- no timezone handling (module uses UTC)
- this module works only on perls with 64-bit integers, check `perl -V:ivsize` (should be `ivsize='8'`)
- no chance for nanoseconds precision, maybe in a separate module e.g. `PDL::DateTime::Ns`

# FUNCTIONS

## new

    my $p = PDL::DateTime->new($pdl_or_array_ref);
    # input data = microseconds (LongLong) since 1970-01-01T00:00:00Z (positive or negative)
    # input data are always converted to LongLong

## new\_from\_epoch

    my $p = PDL::DateTime->new_from_epoch($pdl_or_array_ref);
    # BEWARE: precision in miliseconds only!
    # input data = seconds (int or double) since 1970-01-01T00:00:00Z (positive or negative)

## new\_from\_ratadie

    my $p = PDL::DateTime->new_from_ratadie($pdl_or_array_ref);
    # BEWARE: precision in miliseconds only!
    # input data = days (int or double) since January 1, 0001 AD 00:00

See [https://en.wikipedia.org/wiki/Rata\_Die](https://en.wikipedia.org/wiki/Rata_Die)

## new\_from\_serialdate

    my $p = PDL::DateTime->new_from_serialdate($pdl_or_array_ref);
    # BEWARE: precision in miliseconds only!
    # input data = days (int or double) since January 1, 0000 AD 00:00

See [http://www.mathworks.com/help/finance/handling-and-converting-dates.html](http://www.mathworks.com/help/finance/handling-and-converting-dates.html)

## new\_from\_juliandate

    my $p = PDL::DateTime->new_from_juliandate($pdl_or_array_ref);
    # BEWARE: precision in miliseconds only!
    # input data = days (int or double) since November 24, 4714 BC 12:00

See [https://en.wikipedia.org/wiki/Julian\_day](https://en.wikipedia.org/wiki/Julian_day)

## new\_from\_datetime

    my $p = PDL::DateTime->new_from_datetime($array_ref);
    # input data = array of ISO 8601 date time strings

Supported formats - see [Time::Moment](https://metacpan.org/pod/Time::Moment#from_string).

## new\_from\_parts

    my $p = PDL::DateTime->new_from_parts($y, $m, $d, $H, $M, $S, $U);
    # all arguments are either piddles or array refs
    # $y .. years (1..9999)
    # $m .. months (1..12)
    # $d .. days (1..31)
    # $H .. hours (0..23)
    # $M .. minutes (0..59)
    # $S .. seconds (0..59)
    # $U .. microseconds (0..999999)

## new\_from\_ymd

    my $p = PDL::DateTime->new_from_ymd($ymd);
    # BEWARE: handles only dates!
    # $ymd (piddle or array ref) with dates like:
    # [ 20150831, 20150901, 20150902 ]

## new\_sequence

    my $p = PDL::DateTime->new_sequence($start, $count, $unit, $step);
    # $start .. ISO 8601 date time string (starting datetime) or 'now'
    # $count .. length of the sequence (incl. starting point)
    # $unit  .. step unit 'year', 'month', 'week', 'day', 'hour', 'minute', 'second'
    # $step  .. how many units there are between two seq elements (default: 1)

## double\_epoch

    my $dbl = $p->double_epoch;
    # BEWARE: precision loss, before exporting the time precision is truncated to miliseconds!
    # returns Double piddle

## double\_ratadie

    my $dbl = $p->double_ratadie;
    # BEWARE: precision loss, before exporting the time precision is truncated to miliseconds!
    # returns Double piddle

## double\_serialdate

    my $dbl = $p->double_serialdate;
    # BEWARE: precision loss, before exporting the time precision is truncated to miliseconds!
    # returns Double piddle

## double\_juliandate

    my $dbl = $p->double_juliandate;
    # BEWARE: precision loss, before exporting the time precision is truncated to miliseconds!
    # returns Double piddle

## dt\_ymd

    my ($y, $m, $d) = $p->dt_ymd;
    # returns 3 piddles: $y Short, $m Byte, $d Byte

## dt\_hour

    my $H = $p->dt_hour;
    # returns Byte piddle (values 0 .. 23)

## dt\_minute

    my $M = $p->dt_minute;
    # returns Byte piddle (values 0 .. 59)

## dt\_second

    my $S = $p->dt_second;
    # returns Byte piddle (values 0 .. 59)

## dt\_microsecond

    my $U = $p->dt_microsecond;
    # returns Long piddle (values 0 .. 999_999)

## dt\_day\_of\_week

    my $wd = $p->dt_day_of_week;
    # returns Byte piddle (values 1=Mon .. 7=Sun)

## dt\_day\_of\_year

    my $wd = $p->dt_day_of_year;
    # returns Short piddle (values 1..366)

## dt\_add

    my $p->dt_add($num, $unit);
    # adds $num datetime units
    # $unit .. "year", "month", "week", "day", "hour", "minute", "second", "millisecond", "microsecond"

    my $p->dt_add(day => 2);
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2015-08-22T23:24:25.123456Z

    my $p->dt_add(day => 2, year => 3, month => 1);
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2018-09-22T23:24:25.123456Z

    #NOTE: supports also C<inplace>
    $p->inplace->dt_add(day => 2);

## dt\_truncate

    my $p->dt_truncate($unit);
    # $unit .. "year", "month", "week", "day", "hour", "minute", "second", "millisecond", "microsecond"

    my $p->dt_truncate('minute');
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2015-08-20T23:24:00.000000Z

    #NOTE: supports also C<inplace>
    $p->inplace->dt_truncate('minute');

## dt\_unpdl

    my $array = $p->dt_unpdl;
    my $array = $p->dt_unpdl($format);
    
    my $array = $p->dt_unpdl('%y-%m-%d %H:%M:%S');
    # returns perl arrayref with ISO 8601 date time strings

    my $array = $p->dt_unpdl('auto');
    # uses ISO 8601 format autodetected to be as short as possible
    # e.g. 2015-09-07T22:53 when all piddle values have 0 seconds and 0 microseconds
    # $format 'auto' is default when dt_unpdl is called without param
    
    my $array = $p->dt_unpdl('epoch');
    # returns perl arrayref (not a piddle) with epoch seconds as double
    # BEWARE: precision loss, before exporting the time precision is truncated to miliseconds!
    
    my $array = $p->dt_unpdl('epoch_int');
    # returns perl arrayref (not a piddle) with epoch seconds as integer values
    # BEWARE: precision loss, before exporting the time precision is truncated to seconds!

    my $array = $p->dt_unpdl('Time::Moment');
    # returns perl arrayref with Time::Moment objects

See [Time::Moment](https://metacpan.org/pod/Time::Moment#strftime) (which we use for stringification) for supported format.

## dt\_at

    my $datetime = $p->dt_at(@coords)
    #or
    my $datetime = $p->dt_at(@coords, $format)
    # returns ISO 8601 date time string for value at given piddle co-ordinates
    # optional $format arg - same as by dt_unpdl

## dt\_set

    $p->dt_set(@coords, $datetime_or_epoch);
    # sets $datetime_or_epoch as value at given piddle co-ordinates
    # $datetime_or_epoch can be ISO 8601 string or epoch seconds (double or int)

# SEE ALSO

[PDL](https://metacpan.org/pod/PDL)

# LICENSE

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

# COPYRIGHT

2015+ KMX <kmx@cpan.org>
