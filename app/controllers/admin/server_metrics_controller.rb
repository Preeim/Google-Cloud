# ==============================================================================
# Bánk's Repository - Szerver Monitorozó Vezérlő (Admin::ServerMetricsController)
# ==============================================================================
# Adminisztrátori felület és REST API a szerver hardveres, hálózati és folyamat
# telemetriájának valós idejű megjelenítéséhez és lekérdezéséhez.
# Biztonság: Admin::BaseController által kötelezően védve (require_admin!).
# ==============================================================================

module Admin
  class ServerMetricsController < BaseController
    # GET /bank-admin/server_metrics vagy /bank-admin/system
    def index
      @metrics = ServerMetricsService.collect_metrics
    end

    # GET /bank-admin/server_metrics/data.json
    # Polling és azonnali REST lekérési végpont fallback vagy integrációs célokra
    def data
      metrics = ServerMetricsService.collect_metrics
      render json: metrics
    end
  end
end

