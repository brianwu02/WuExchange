defmodule WuExchangeWeb.PageController do
  use WuExchangeWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
