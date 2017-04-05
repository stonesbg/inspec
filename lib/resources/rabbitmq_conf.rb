# encoding: utf-8
# author: Dominik Richter
# author: Christoph Hartmann

require 'utils/erlang_parser'

module Inspec::Resources
  class RabbitmqConf < Inspec.resource(1)
    name 'rabbitmq_config'
    desc 'Use the rabbitmq_config InSpec resource to test configuration data '\
         'for the RabbitMQ service located in /etc/rabbitmq/rabbitmq.config on '\
         'Linux and UNIX platforms.'
    example "
      describe rabbitmq_config.params('rabbit', 'ssl_listeners') do
        it { should cmp 5671 }
      end
    "

    def initialize(conf_path = nil)
      @conf_path = conf_path || '/etc/rabbitmq/rabbitmq.config'
    end

    def params(*opts)
      opts.inject(read_params) do |res, nxt|
        res.respond_to?(:key) ? res[nxt] : nil
      end
    end

    def to_s
      'RabbitMQ Configuration'
    end

    private

    def read_content
      return @content if defined?(@content)
      file = inspec.file(@conf_path)
      if !file.file?
        return skip_resource "Can't find file \"#{@conf_path}\""
      end

      @content = file.content
      if @content.empty? && !file.empty?
        return skip_resource "Can't read file \"#{@conf_path}\""
      end

      @content
    end

    def read_params
      return @params if defined?(@params)
      return @params = {} if read_content.nil?
      lex = ErlangParser.new.parse(read_content)
      tree = ErlangTransform.new.apply(lex)
      @params = turn_to_hash(tree)
    rescue Parslet::ParseFailed
      raise "Cannot parse RabbitMQ config: \"#{read_content}\""
    end

    def turn_to_hash(t)
      if t.is_a?(Array) && t.all? { |x| x.class == ErlangTransform::Tuple && x.length == 2 }
        Hash[t.map { |i| [i[0], turn_to_hash(i[1])] }]
      else
        t
      end
    end
  end
end
