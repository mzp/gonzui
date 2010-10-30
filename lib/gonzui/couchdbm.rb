# -*- coding: utf-8 -*-
#
# couchdbm.rb - CouchDB implementation of gonzui DB
#
# Copyright (C) 2010 MIZUNO Hiroki <mzp@ocaml.jp>
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'json'
require 'net/http'
require "base64"

module Gonzui
  class CouchClient
    def initialize(host, port, options = nil)
      @host = host
      @port = port
      @options = options
    end

    def delete(uri)
      request(Net::HTTP::Delete.new(uri))
    end

    def get(uri)
      request(Net::HTTP::Get.new(uri))
    end

    def put(uri, json)
      req = Net::HTTP::Put.new(uri)
      req["content-type"] = "application/json"
      req.body = json
      request(req)
    end

    def post(uri, json)
      req = Net::HTTP::Post.new(uri)
      req["content-type"] = "application/json"
      req.body = json
      request(req)
    end

    def request(req)
      res = Net::HTTP.start(@host, @port) { |http|http.request(req) }
      unless res.kind_of?(Net::HTTPSuccess)
        handle_error(req, res)
      end
      res
    end

    def exists?(uri)
      get(uri)
      true
    rescue
      false
    end

    private

    def handle_error(req, res)
      e = RuntimeError.new("#{res.code}:#{res.message}\nMETHOD:#{req.method}\nURI:#{req.path}\n#{res.body}")
      raise e
    end
  end

  class CouchView
    def initialize(client, uri, opts={})
      @client = client
      @uri    = uri
      @opts   = opts

      unless @client.exists? @uri then
        @client.put(@uri,"{}")
      end
    end

    def []=(k, value)
      json      = doc
      if @opts[:dup] then
        k2 = key k
        json[k2] = json.fetch(k2,[]) + [ store(value) ]
      else
        json[key(k)] = store(value)
      end
      @client.put @uri, json.to_json
    end

    def [](k)
      fetch doc[key(k)]
    end

    def include?(v)
      doc.include? key(v)
    end

    def each_value(&f)
      self.each{|_,value|
        f[value]
      }
    end

    def each(&f)
      doc.each{|k,v|
        unless k =~ /\A_/ then
          f[fetch_key(k), fetch(v)]
        end
      }
    end

    def duplicates(k)
      self[k]
    end

    def each_by_prefix(prefix,&f)
      self.each do|key,value|
        if key[0, prefix.length] == prefix then
          f[key,value]
        end
      end
    end

    private
    def doc
      JSON.parse(@client.get(@uri).body)
    end

    def key(key)
      @opts[:key_store][key]
    end

    def fetch_key(key)
      @opts[:key_fetch][key]
    end

    def store(value)
      if value then
        Base64::encode64 @opts[:value_store][value]
      end
    end

    def fetch(value)
      case value
      when NilClass
        nil
      when Array
        value.map{|item|
          @opts[:value_fetch][Base64::decode64(item)]
        }
      else
        @opts[:value_fetch][Base64::decode64(value)]
      end
    end
  end

  class CouchDBM < AbstractDBM
    def initialize(config, read_only = false)
      @config    = config
      @read_only = read_only
      @client    = CouchClient.new("localhost", "5984")
      unless @client.exists? '/gonzui' then
        @client.put('/gonzui/','')
      end
      super
    end

    def close
    end

    def do_open_db(name, key_type, value_type, dup)
      CouchView.new(@client,
                    uri(name),
                    :dup => dup,
                    :key_store => wrap(key_type.store),
                    :key_fetch => wrap(key_type.fetch),
                    :value_store => wrap(value_type.store),
                    :value_fetch => wrap(value_type.fetch))
    end

    def find_all_by_prefix(pattern)
      results = []
      self.word_wordid.each_by_prefix(pattern) {|word, word_id|
        results.concat(collect_all_results(word_id))
      }
      return results
    end

    private
    def wrap(f)
      f || proc{|x| x}
    end

    def uri(name)
      "/gonzui/#{name}"
    end
  end
end
