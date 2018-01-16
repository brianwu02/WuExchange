defmodule WuExchangeWeb.Webhook.TwilioView do
  use WuExchangeWeb, :view
  alias WuExchangeWeb.Webhook.TwilioView

  def render("index.json", %{twilios: twilios}) do
    %{data: render_many(twilios, TwilioView, "twilio.json")}
  end

  def render("show.json", %{twilio: twilio}) do
    %{data: render_one(twilio, TwilioView, "twilio.json")}
  end

  def render("twilio.json", %{twilio: twilio}) do
    %{id: twilio.id}
  end
end
