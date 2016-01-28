module RiemannRails
	module Rails
		##
		# Contains helper methods that can be used inside Rails controllers to send
		# notices to Riemann. The main benefit of using them instead of the direct
		# API is that they automatically add information from the Rack environment
		# to notices.
		module ActionController
			private

			##
			# A helper method for sending notices to Riemann *asynchronously*.
			# Attaches information from the Rack env.
			# @see Riemann#notify, #notify_airbrake_sync
			def notify_riemann(exception, parameters = {}, notifier = :default)
				RiemannRails.notify(build_notice(exception), parameters, notifier)
			end

			##
			# A helper method for sending notices to Riemann *synchronously*.
			# Attaches information from the Rack env.
			# @see Riemann#notify_sync, #notify_airbrake
			def notify_riemann_sync(exception, parameters = {}, notifier = :default)
				RiemannRails.notify_sync(build_notice(exception), parameters, notifier)
			end

			##
			# @param [Exception] exception
			# @return [Riemann::Notice] the notice with information from the Rack env
			def build_notice(exception)
				RiemannRails::Rack::NoticeBuilder.new(request.env).build_notice(exception)
			end
		end
	end
end
