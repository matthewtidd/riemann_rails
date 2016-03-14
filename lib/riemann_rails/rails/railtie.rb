module RiemannRails
	module Rails
		##
		# This railtie works for any Rails application that supports railties (Rails
		# 3.2+ apps). It makes Riemann Ruby work with Rails and report errors
		# occurring in the application automatically.
		class Railtie < ::Rails::Railtie

			config.riemann_rails = ActiveSupport::OrderedOptions.new

			config.riemann_rails.enabled = true
			config.riemann_rails.host = "localhost"
			config.riemann_rails.port = 5555
			config.riemann_rails.service_name = "Rails"
			config.riemann_rails.ttl = 5000
			config.riemann_rails.transport = :udp

			initializer('riemann_rails.middleware') do |app|
				# Since Rails 3.2 the ActionDispatch::DebugExceptions middleware is
				# responsible for logging exceptions and showing a debugging page in
				# case the request is local. We want to insert our middleware after
				# DebugExceptions, so we don't notify Riemann about local requests.

				if ::Rails.version.start_with?('5.')
					# Avoid the warning about deprecated strings.
					app.config.middleware.insert_after(
						ActionDispatch::DebugExceptions, RiemannRails::Rack::Middleware
					)
				else
					app.config.middleware.insert_after(
						ActionDispatch::DebugExceptions, 'RiemannRails::Rack::Middleware'
					)
				end
			end

			initializer('riemann_rails.action_controller') do
				ActiveSupport.on_load(:action_controller) do
					# Patches ActionController with methods that allow us to retrieve
					# interesting request data. Appends that information to notices.
					require 'riemann_rails/rails/action_controller'
					include RiemannRails::Rails::ActionController
				end
			end

			initializer('riemann_rails.active_record') do
				ActiveSupport.on_load(:active_record) do
					# Reports exceptions occurring in some bugged ActiveRecord callbacks.
					# Applicable only to the versions of Rails lower than 4.2.
					require 'riemann_rails/rails/active_record'
					include RiemannRails::Rails::ActiveRecord
				end
			end

			initializer('riemann_rails.active_job') do
				ActiveSupport.on_load(:active_job) do
					# Reports exceptions occurring in ActiveJob jobs.
					require 'riemann_rails/rails/active_job'
					include RiemannRails::Rails::ActiveJob
				end
			end

			initializer("riemann_rails.initialize_riemann") do |app|
				app_cfg = app.config.riemann_rails
				@@host = app_cfg.host
				@@port = app_cfg.port
				@@service_name = app_cfg.service_name
				@@env = app_cfg.env
				@@ttl = app_cfg.ttl
				@@transport = app_cfg.transport
				@@hostname = get_hostname
				@@client = Riemann::Client.new(:host => app_cfg.host, :port => app_cfg.port)
			end

			initializer("riemann_rails.subscribe") do |app|
				ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args|
					RiemannRails::Rails::Railtie.process_action_action_controller(*args)
				end
				#ActiveSupport::Notifications.subscribe "deliver.action_mailer" do |*args|
				#	self.deliver_action_mailer(*args)
				#end
			end

			def self.total_time(start, finish)
				(finish - start) * 1000
			end

			def self.process_action_action_controller(channel, start, finish, id, payload)
				tags = [payload[:controller], payload[:action]]
				service_name = tags.join(".")
				tags << "rails"
				tags << "rateable"
				state = !payload[:exception].nil? ? "critical" : "ok"
				data = {:controller_action => "#{payload[:controller]}.#{payload[:action]}"}
				self.post (tags.dup << 'http_status'), state, payload[:status], "#{service_name}.http_status", nil, data
				self.post (tags.dup << 'view_runtime'), state, payload[:view_runtime], "#{service_name}.view_runtime", nil, data
				self.post (tags.dup << 'request_runtime'), state, self.total_time(start, finish), "#{service_name}.total_time", nil, data
				self.post (tags.dup << 'db_runtime'), state, payload[:db_runtime], "#{service_name}.db_runtime", nil, data
				self.post (tags.dup << 'sap_runtime'), state, payload[:sap_runtime], "#{service_name}.sap_runtime", nil, data
			end

			def self.post(tags, state, metric, service='', description=nil, data = {})
				event = {
					host: @@hostname,
					state: state,
					metric: metric,
					ttl: @@ttl,
					tags: (tags.dup << @@env).flatten,
					service: "#{@@service_name}.#{service}"
				}
				event.merge! data
				puts "RIEMANN DATA = #{event}"
				event[:description] = description if description
				if @@transport == :tcp || event[:description]
					begin
						@@client.tcp << event
					rescue Riemann::Client::TcpSocket::Error
					end
				else
					@@client << event
				end
			end

			def get_hostname
				`hostname`.strip
			end
		end
	end
end
