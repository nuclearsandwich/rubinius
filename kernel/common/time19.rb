# -*- encoding: us-ascii -*-

class Time
  def self.at(sec, usec=undefined)
    if usec.equal?(undefined)
      if sec.kind_of?(Time)
        return duplicate(sec)
      elsif sec.kind_of?(Integer)
        return specific(sec, 0, false)
      end
    end

    usec = 0 if usec.equal?(undefined)

    s = Rubinius::Type.coerce_to_exact_num(sec)
    u = Rubinius::Type.coerce_to_exact_num(usec)

    sec       = s.to_i
    nsec_frac = s % 1.0

    sec -= 1 if s < 0 && nsec_frac > 0
    nsec = (nsec_frac * 1_000_000_000 + 0.5).to_i + (u * 1000).to_i

    sec += nsec / 1_000_000_000
    nsec %= 1_000_000_000

    specific(sec, nsec, false)
  end

  def self.from_array(sec, min, hour, mday, month, year, nsec, is_dst, from_gmt)
    Rubinius.primitive :time_s_from_array

    if sec.kind_of?(Integer) || nsec
      sec  = Rubinius::Type.coerce_to sec, Integer, :to_i
      nsec ||= 0

      sec  = sec + (nsec / 1000000000)
      nsec = nsec % 1000000000
    else
      float = FloatValue(sec)
      sec       = float.to_i
      nsec_frac = float % 1.0

      if float < 0 && nsec_frac > 0
        sec -= 1
      end

      nsec = (nsec_frac * 1_000_000_000 + 0.5).to_i
    end

    from_array(sec, min, hour, mday, month, year, nsec, is_dst, from_gmt)
  end

  def inspect
    if @is_gmt
      strftime("%Y-%m-%d %H:%M:%S UTC")
    else
      strftime("%Y-%m-%d %H:%M:%S %z")
    end
  end

  alias_method :to_s, :inspect

  def nsec
    Rubinius.primitive :time_nseconds
    raise PrimitiveFailure, "Time#nsec failed"
  end

  alias_method :tv_nsec, :nsec

  def subsec
    if nsec == 0
      0
    else
      Rational(nsec, 1_000_000_000)
    end
  end

  def sunday?
    wday == 0
  end

  def monday?
    wday == 1
  end

  def tuesday?
    wday == 2
  end

  def wednesday?
    wday == 3
  end

  def thursday?
    wday == 4
  end

  def friday?
    wday == 5
  end

  def saturday?
    wday == 6
  end

  def to_r
    to_f.to_r
  end

  def +(arg)
    raise TypeError, 'time + time?' if arg.kind_of?(Time)

    case arg
    when NilClass
      raise TypeError, "can't convert nil into an exact number"
    when String
      raise TypeError, "can't convert String into an exact number"
    when Integer
      other_sec = arg
      other_nsec = 0
    else
      arg = Rubinius::Type.coerce_to arg, Rational, :to_r
      other_sec, nsec_frac = arg.divmod(1)
      other_nsec = (nsec_frac * 1_000_000_000).to_i
    end

    # Don't use self.class, MRI doesn't honor subclasses here
    Time.specific(seconds + other_sec, nsec + other_nsec, @is_gmt)
  end

  def -(other)
    case other
    when NilClass
      raise TypeError, "can't convert nil into an exact number"
    when String
      raise TypeError, "can't convert String into an exact number"
    when Time
      (seconds - other.seconds) + ((usec - other.usec) * 0.000001)
    when Integer
      # Don't use self.class, MRI doesn't honor subclasses here
      Time.specific(seconds - other, nsec, @is_gmt)
    else
      other = Rubinius::Type.coerce_to other, Rational, :to_r

      other_sec, nsec_frac = other.divmod(1)
      other_nsec = (nsec_frac * 1_000_000_000 + 0.5).to_i

      # Don't use self.class, MRI doesn't honor subclasses here
      Time.specific(seconds - other_sec, nsec - other_nsec, @is_gmt)
    end
  end

  def <=>(other)
    if other.kind_of? Time
      c = (seconds <=> other.seconds)
      return c unless c == 0
      usec <=> other.usec
    else
      r = (other <=> self)
      return nil if r == nil
      return -1 if r > 0
      return  1 if r < 0
      0
    end
  end
end
