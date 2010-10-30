#
# bdbdbm.rb - bdb implementation of gonzui DB
#
# Copyright (C) 2004-2005 Satoru Takabayashi <satoru@namazu.org>
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'dbm'
module Gonzui
  class CouchView
    def []=(key, value)
    end

    def [](key)
    end

    def include?(key)
      false
    end

    def each_value(&f)
    end

    def duplicates(key)
      []
    end
  end

  class CouchDBM < AbstractDBM
    def initialize(config, read_only = false)
      super
    end

    def has_package?(name)
    end

    def close
    end

    def do_open_db(name, key_type, value_type, dupsort)
      CouchView.new
    end
  end
end
