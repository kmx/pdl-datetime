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

# SYNOPSIS

    use 5.010;
    use PDL;
    use PDL::DateTime;

    my $dt_1 = PDL::DateTime->new_sequence('2015-09-20T15:45', 5, 'hour');
    say $dt_1;
    # [ 2015-09-20T15:45 2015-09-20T16:45 2015-09-20T17:45 2015-09-20T18:45 2015-09-20T19:45 ]

    say $dt_1->where($dt_1 > '2015-09-20T17:00');
    # [ 2015-09-20T17:45 2015-09-20T18:45 2015-09-20T19:45 ]

    say $dt_1->dt_hour;
    # [15 16 17 18 19]

    say $dt_1->dt_minute;
    # [45 45 45 45 45]

    say $dt_1->dt_add(year=> 4, month=>6, day=>3);
    # [ 2020-03-23T15:45 2020-03-23T16:45 2020-03-23T17:45 2020-03-23T18:45 2020-03-23T19:45 ]

    my $dt_2 = PDL::DateTime->new_sequence('2015-11-22T23:23:23.654321', 4, 'day');
    say $dt_2;
    # [ 2015-11-22T23:23:23.654321 2015-11-23T23:23:23.654321 2015-11-24T23:23:23.654321 2015-11-25T23:23:23.654321 ]

    say $dt_2->dt_align('day');
    # [ 2015-11-22 2015-11-23 2015-11-24 2015-11-25 ]

    say $dt_2->dt_align('hour');
    # [ 2015-11-22T23:00 2015-11-23T23:00 2015-11-24T23:00 2015-11-25T23:00 ]

    say $dt_2->dt_align('minute');
    # [ 2015-11-22T23:23 2015-11-23T23:23 2015-11-24T23:23 2015-11-25T23:23 ]

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
    # $unit  .. step unit 'year', 'quarter', 'month', 'week',
    #                     'day', 'hour', 'minute', 'second'
    # $step  .. how many units there are between two seq elements (default: 1)

## double\_epoch

    my $dbl = $p->double_epoch;
    # BEWARE: precision loss, before exporting the time is truncated to miliseconds!
    # returns Double piddle

## longlong\_epoch

    my $epoch = $p->longlong_epoch;
    # BEWARE: precision loss, before exporting the time is truncated to seconds!
    # returns LongLong piddle

    # NOTE: $p->longlong_epoch is equivalent to: longlong(floor($p->double_epoch))
    # 1969-12-31T23:59:58        double_epoch = -2.0      longlong_epoch = -2
    # 1969-12-31T23:59:58.001    double_epoch = -1.999    longlong_epoch = -2
    # 1969-12-31T23:59:58.999    double_epoch = -1.001    longlong_epoch = -2
    # 1969-12-31T23:59:59        double_epoch = -1.0      longlong_epoch = -1
    # 1969-12-31T23:59:59.001    double_epoch = -0.999    longlong_epoch = -1
    # 1969-12-31T23:59:59.999    double_epoch = -0.001    longlong_epoch = -1
    # 1970-01-01T00:00:00        double_epoch =  0.0      longlong_epoch =  0
    # 1970-01-01T00:00:00.001    double_epoch =  0.001    longlong_epoch =  0
    # 1970-01-01T00:00:00.999    double_epoch =  0.999    longlong_epoch =  0
    # 1970-01-01T00:00:01        double_epoch =  1.0      longlong_epoch =  1

## double\_ratadie

    my $dbl = $p->double_ratadie;
    # BEWARE: precision loss, before exporting the time is truncated to miliseconds!
    # returns Double piddle

## double\_serialdate

    my $dbl = $p->double_serialdate;
    # BEWARE: precision loss, before exporting the time is truncated to miliseconds!
    # returns Double piddle

## double\_juliandate

    my $dbl = $p->double_juliandate;
    # BEWARE: precision loss, before exporting the time is truncated to miliseconds!
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

    my $p->dt_add($unit, $num);
    # adds $num datetime units
    # $num can be positive (addition) or negative (subtraction)
    # $unit .. 'year', 'quarter', 'month', 'week', 'day', 'hour',
    #          'minute', 'second', 'millisecond', 'microsecond'

    my $p->dt_add(day => 2);
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2015-08-22T23:24:25.123456Z

    my $p->dt_add(day => -2);
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2015-08-18T23:24:25.123456Z

    my $p->dt_add(day => 2, year => 3, month => 1);
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2018-09-22T23:24:25.123456Z

    #NOTE: supports also inplace
    $p->inplace->dt_add(day => 2);

## dt\_align

    my $p->dt_align($unit);
    # $unit .. 'year', 'quarter', 'month', 'week', 'day', 'hour',
    #          'minute', 'second', 'millisecond', 'microsecond'

    my $p->dt_align('minute');
    # turns e.g. 2015-08-20T23:24:25.123456Z
    # into       2015-08-20T23:24:00.000000Z

    # for units 'year', 'quarter', 'month' there is second optional param
    # let's have: 2015-08-20T23:24:25.123456Z
    $p->dt_align('month');      # -> 2015-08-01
    $p->dt_align('month', 1);   # -> 2015-08-31
    $p->dt_align('quarter');    # -> 2015-07-01
    $p->dt_align('quarter', 1); # -> 2015-09-30
    $p->dt_align('year');       # -> 2015-01-01
    $p->dt_align('year', 1);    # -> 2015-12-31

    #NOTE: supports also inplace
    $p->inplace->dt_align('minute');

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
    # BEWARE: precision loss, before exporting the time is truncated to miliseconds!

    my $array = $p->dt_unpdl('epoch_int');
    # returns perl arrayref (not a piddle) with epoch seconds as integer values
    # BEWARE: precision loss, before exporting the time is truncated to seconds!

    my $array = $p->dt_unpdl('Time::Moment');
    # returns perl arrayref with Time::Moment objects

See [Time::Moment](https://metacpan.org/pod/Time::Moment#strftime) (which we use for stringification) for supported formats.

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

## dt\_diff

    my $deltas = $p->dt_diff;
    #or
    my $deltas = $p->dt_diff($unit);
    # $unit .. 'week', 'day', 'hour', 'minute', 'second', 'millisecond'

## dt\_periodicity

    my $per = $p->dt_periodicity;
    # estimates the periodicity by calculating the median time between observations
    # returns: "microsecond", "millisecond", "second", "minute"
    #          "hour", "day", "week", "month", "quarter"
    #          or an empty string

## dt\_startpoints

Extract index values corresponding to the first observations given a period specified by `$unit`

    my $end_idx = $p->dt_startpoints($unit);
    # $unit .. accepts same values as dt_align

Example:

    my $dt = PDL::DateTime->new_from_datetime([qw/
       2015-03-24 2015-03-25 2015-03-28 2015-04-01
       2015-04-02 2015-04-30 2015-05-01 2015-05-10
    /]);

    print $dt->dt_startpoints('month');
    # prints: [0 3 6]

    print $dt->dt_startpoints('quarter');
    # prints: [0 3]

## dt\_endpoints

Extract index values corresponding to the last observations given a period specified by `$unit`

    my $end_idx = $p->dt_endpoints($unit);
    # $unit .. accepts same values as dt_align

Example:

    my $dt = PDL::DateTime->new_from_datetime([qw/
       2015-03-24 2015-03-25 2015-03-28 2015-04-01
       2015-04-02 2015-04-30 2015-05-01 2015-05-10
    /]);

    print $dt->dt_endpoints('month');
    # prints: [2 5 7]

    print $dt->dt_endpoints('quarter');
    # prints: [2 7]

## dt\_slices

Combines ["dt\_startpoints"](#dt_startpoints) and ["dt\_endpoints"](#dt_endpoints) and returns 2D piddle like this:

    my $dt = PDL::DateTime->new_from_datetime([qw/
       2015-03-24 2015-03-25 2015-03-28 2015-04-01
       2015-04-02 2015-04-30 2015-05-01 2015-05-10
    /]);

    print $dt->dt_slices('month');
    # [
    #  [0 2]    ... start index == 0, end index == 2
    #  [3 5]    ... start index == 3, end index == 5
    #  [6 7]    ... start index == 6, end index == 7
    # ]

    print $dt->dt_slices('quarter');
    # [
    #  [0 2]
    #  [3 7]
    # ]

## dt\_nperiods

Calculate the number of periods specified by `$unit` in a given time series.
The resulting value is approximate, derived from counting the endpoints.

    $dt->dt_nperiods($unit)
    # $unit .. 'year', 'quarter', 'month', 'week', 'day', 'hour',
    #          'minute', 'second', 'millisecond', 'microsecond'

## is\_increasing

    print $dt->is_increasing ? "is increasing" : "no";
    #or
    print $dt->is_increasing(1) ? "is strictly increasing" : "no";

## is\_decreasing

    print $dt->is_decreasing ? "is decreasing" : "no";
    #or
    print $dt->is_decreasing(1) ? "is strictly decreasing" : "no";

## is\_uniq

    print $dt->is_uniq ? "all items are uniq" : "no";

## is\_regular

    print $dt->is_regular ? "all periods between items are the same" : "no";

# SEE ALSO

[PDL](https://metacpan.org/pod/PDL)

# LICENSE

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

# COPYRIGHT

2015+ KMX <kmx@cpan.org>
