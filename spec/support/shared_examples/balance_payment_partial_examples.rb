# frozen_string_literal: true

shared_examples 'outstanding balance rendering' do
  context 'when the order has outstanding balance' do
    before { allow(order).to receive(:outstanding_balance) { 123 } }

    it 'renders the amount as money' do
      expect(email.body).to include('$123')
    end
  end

  context 'when the order has no outstanding balance' do
    before { allow(order).to receive(:outstanding_balance) { 0 } }

    it 'displays the payment status' do
      expect(email.body).to include(I18n.t(:email_payment_not_paid))
    end
  end
end

shared_examples 'outstanding balance view rendering' do
  context 'when the order has outstanding balance' do
    let(:user) { order.user }

    before { allow(order).to receive(:outstanding_balance) { 123 } }

    it 'renders the amount as money' do
      render
      expect(rendered).to include('$123')
    end
  end

  context 'when the order has no outstanding balance' do
    let(:user) { order.user }

    before { allow(order).to receive(:outstanding_balance) { 0 } }

    it 'renders the amount as money' do
      render
    end

    it 'displays the payment status' do
      render
      expect(rendered).to include(I18n.t(:email_payment_not_paid))
    end
  end
end

shared_examples 'new outstanding balance rendering' do
  context 'when the order has outstanding balance' do
    before { allow(order).to receive(:new_outstanding_balance) { 123 } }

    it 'renders the amount as money' do
      expect(email.body).to include('$123')
    end
  end

  context 'when the order has no outstanding balance' do
    before { allow(order).to receive(:new_outstanding_balance) { 0 } }

    it 'displays the payment status' do
      expect(email.body).to include(I18n.t(:email_payment_not_paid))
    end
  end
end

shared_examples 'new outstanding balance view rendering' do
  context 'when the order has outstanding balance' do
    let(:user) { order.user }

    before { allow(order).to receive(:new_outstanding_balance) { 123 } }

    it 'renders the amount as money' do
      render
      expect(rendered).to include('$123')
    end
  end

  context 'when the order has no outstanding balance' do
    let(:user) { order.user }

    before { allow(order).to receive(:new_outstanding_balance) { 0 } }

    it 'renders the amount as money' do
      render
    end

    it 'displays the payment status' do
      render
      expect(rendered).to include(I18n.t(:email_payment_not_paid))
    end
  end
end