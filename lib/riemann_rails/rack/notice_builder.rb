module RiemannRails
	module Rack
		##
		# A helper class for filling notices with all sorts of useful information
		# coming from the Rack environment.
		class NoticeBuilder
			##
			# @return [String] the name of the host machine
			HOSTNAME = Socket.gethostname.freeze

			##
			# @param [Hash{String=>Object}] rack_env The Rack environment
			def initialize(rack_env)
				@rack_env = rack_env
				@request = ::Rack::Request.new(rack_env)
				@controller = rack_env['action_controller.instance']
				@session = @request.session
			end

			##
			# Adds context, session, params and other fields based on the Rack env.
			#
			# @param [Exception] exception
			# @return [Riemann::Notice] the notice with extra information
			def build_notice(exception)
				name = "exception"
				if @controller
					name = "#{@controller.controller_name}.#{@controller.action_name}"
				end
				description = [exception.to_s, exception.backtrace].join("\n")
				data = {}

				if @request
					params = @request.env['action_dispatch.request.parameters']
					data[:params] = params if params
					data[:url] = @request.url
					if @request.env["action_controller.instance"] && @request.env["action_controller.instance"].current_user
						user = @request.env["action_controller.instance"].current_user
						data[:user] = "#{user.id}/#{user.login}"
					end
				end

				RiemannRails::Rails::Railtie.post(["rails", "exception"], "exception", 1, name, description, data)
			end

			private

			def add_context(notice)
				context = notice[:context]

				context[:url] = @request.url
				context[:userAgent] = @request.user_agent
				context[:hostname] = HOSTNAME

				if @controller
					context[:component] = @controller.controller_name
					context[:action] = @controller.action_name
				end

				nil
			end

			def add_session(notice)
				notice[:session] = @session if @session
			end

			def add_params(notice)
				params = @request.env['action_dispatch.request.parameters']
				notice[:params] = params if params
			end
		end
	end
end
