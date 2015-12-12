module Spree
  Payment.class_eval do
    # Pin payments lacks void and credit methods, but it does have refund
    # Here we swap credit out for refund and remove void as a possible action
    def actions_with_pin_payment_adaptations
      actions = actions_without_pin_payment_adaptations
      if payment_method.is_a? Gateway::Pin
        actions << 'refund' if actions.include? 'credit'
        actions.reject! { |a| ['credit', 'void'].include? a }
      end
      actions
    end
    alias_method_chain :actions, :pin_payment_adaptations


    def refund!(refund_amount=nil)
      protect_from_connection_error do
        check_environment

        refund_amount = calculate_refund_amount(refund_amount)

        if payment_method.payment_profiles_supported?
          response = payment_method.refund((refund_amount * 100).round, source, response_code, gateway_options)
        else
          response = payment_method.refund((refund_amount * 100).round, response_code, gateway_options)
        end

        record_response(response)

        if response.success?
          self.class.create({ order: order,
                              source: self,
                              payment_method: payment_method,
                              amount: refund_amount.abs * -1,
                              response_code: response.authorization,
                              state: 'completed' }, without_protection: true)
        else
          gateway_error(response)
        end
      end
    end


    private

    def calculate_refund_amount(refund_amount=nil)
      refund_amount ||= credit_allowed >= order.outstanding_balance.abs ? order.outstanding_balance.abs : credit_allowed.abs
      refund_amount.to_f
    end

  end
end
