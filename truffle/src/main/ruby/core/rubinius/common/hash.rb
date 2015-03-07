# Copyright (c) 2007-2014, Evan Phoenix and contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of Rubinius nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Only part of Rubinius' hash.rb

class Hash

  alias_method :store, :[]=

  # Used internally to get around subclasses redefining #[]=
  alias_method :__store__, :[]=

  def merge!(other)
    Rubinius.check_frozen

    other = Rubinius::Type.coerce_to other, Hash, :to_hash

    if block_given?
      other.each_item do |item|
        key = item.key
        if key? key
          __store__ key, yield(key, self[key], item.value)
        else
          __store__ key, item.value
        end
      end
    else
      other.each_item do |item|
        __store__ item.key, item.value
      end
    end
    self
  end

  alias_method :update, :merge!

  def each_key
    return to_enum(:each_key) unless block_given?

    each_item { |item| yield item.key }
    self
  end

  def each_value
    return to_enum(:each_value) unless block_given?

    each_item { |item| yield item.value }
    self
  end

  def keys
    ary = []
    each_item do |item|
      ary << item.key
    end
    ary
  end

  def values
    ary = []

    each_item do |item|
      ary << item.value
    end

    ary
  end

  def invert
    inverted = {}
    each_item do |item|
      inverted[item.value] = item.key
    end
    inverted
  end

  def to_a
    ary = []

    each_item do |item|
      ary << [item.key, item.value]
    end

    Rubinius::Type.infect ary, self
    ary
  end

  def to_h
    if instance_of? Hash
      self
    else
      Hash.allocate.replace(to_hash)
    end
  end

  def default(key=undefined)
    if @default_proc and !undefined.equal?(key)
      @default_proc.call(self, key)
    else
      @default
    end
  end

  # Sets the default proc to be executed on each key lookup
  def default_proc=(prc)
    Rubinius.check_frozen
    unless prc.nil?
      prc = Rubinius::Type.coerce_to prc, Proc, :to_proc

      if prc.lambda? and prc.arity != 2
        raise TypeError, "default proc must have arity 2"
      end
    end

    @default = nil
    @default_proc = prc
  end

  def inspect
    out = []
    return '{...}' if Thread.detect_recursion self do
      each_item do |item|
        str =  item.key.inspect
        str << '=>'
        str << item.value.inspect
        out << str
      end
    end

    ret = "{#{out.join ', '}}"
    Rubinius::Type.infect(ret, self) unless empty?
    ret
  end

  alias_method :to_s, :inspect

  def hash
    val = size
    Thread.detect_outermost_recursion self do
      each_item do |item|
        val ^= item.key.hash
        val ^= item.value.hash
      end
    end

    val
  end

  def reject(&block)
    return to_enum(:reject) unless block_given?

    hsh = dup.delete_if(&block)
    hsh.taint if tainted?
    hsh
  end

  def reject!(&block)
    return to_enum(:reject!) unless block_given?

    Rubinius.check_frozen

    unless empty?
      size = @size
      delete_if(&block)
      return self if size != @size
    end

    nil
  end

  def delete_if(&block)
    return to_enum(:delete_if) unless block_given?

    Rubinius.check_frozen

    select(&block).each { |k, v| delete k }
    self
  end

  # Returns true if there are no entries.
  def empty?
    @size == 0
  end

  def assoc(key)
    each_item { |e| return e.key, e.value if key == e.key }
  end

  def rassoc(value)
    each_item { |e| return e.key, e.value if value == e.value }
  end

  def sort(&block)
    to_a.sort(&block)
  end

  def values_at(*args)
    args.map do |key|
      if item = find_item(key)
        item.value
      else
        default key
      end
    end
  end

  alias_method :indices, :values_at
  alias_method :indexes, :values_at

  def self.try_convert(obj)
    Rubinius::Type.try_convert obj, Hash, :to_hash
  end

  alias_method :store, :[]=

  def select
    return to_enum(:select) unless block_given?

    selected = Hash.allocate

    each_item do |item|
      if yield(item.key, item.value)
        selected[item.key] = item.value
      end
    end

    selected
  end

  def select!
    return to_enum(:select!) unless block_given?

    Rubinius.check_frozen

    return nil if empty?

    size = @size
    each_item { |e| delete e.key unless yield(e.key, e.value) }
    return nil if size == @size

    self
  end

  def key?(key)
    find_item(key) != nil
  end

  alias_method :has_key?, :key?
  alias_method :include?, :key?
  alias_method :member?, :key?

  def index(value)
    each_item do |item|
      return item.key if item.value == value
    end
  end

  alias_method :key, :index

  def keep_if
    return to_enum(:keep_if) unless block_given?

    Rubinius.check_frozen

    each_item { |e| delete e.key unless yield(e.key, e.value) }

    self
  end

  def flatten(level=1)
    to_a.flatten(level)
  end

end
