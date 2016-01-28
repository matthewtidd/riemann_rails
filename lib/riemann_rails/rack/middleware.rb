module RiemannRails
	module Rack
		##
		# Riemann Rack middleware for Rails and Sinatra applications (or any other
		# Rack-compliant app). Any errors raised by the upstream application will be
		# delivered to Riemann and re-raised.
		#
		# The middleware automatically sends information about the framework that
		# uses it (name and version).
		class Middleware
			def initialize(app)
				@app = app
			end

			##
			# Rescues any exceptions, sends them to Riemann and re-raises the
			# exception.
			# @param [Hash] env the Rack environment
			def call(env)
				begin
					response = @app.call(env)
				rescue Exception => ex
					notify_riemann(ex, env)
					raise ex
				end

				# The internal framework middlewares store exceptions inside the Rack
				# env. See: https://goo.gl/Kd694n
				exception = env['action_dispatch.exception'] || env['sinatra.error']
				notify_riemann(exception, env) if exception

				response
			end

			private

			def notify_riemann(exception, env)
				notice = NoticeBuilder.new(env).build_notice(exception)
			end
		end
	end
end
