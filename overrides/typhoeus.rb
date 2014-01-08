module Typhoeus
  class Hydra

    module Queueable

      def processing_requests
        @processing_requests ||= []
      end

      def dequeue
        unless queued_requests.empty?
          req = queued_requests.shift
          req.hydra = self
          processing_requests << req
          add(req)
        end
      end
    end
  end
end