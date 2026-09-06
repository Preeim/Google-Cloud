# ==============================================================================
# Bánk's Repository - Szerver Monitorozó Csatorna (ServerMetricsChannel)
# ==============================================================================
# Valós idejű Action Cable WebSocket csatorna a hardveres és hálózati erőforrások
# folyamatos streameléséhez. Szigorúan csak bejelentkezett, rendszergazdai (admin)
# jogosultsággal rendelkező felhasználók csatlakozhatnak.
# ==============================================================================

class ServerMetricsChannel < ApplicationCable::Channel
  STREAM_NAME = "server_metrics_channel"

  def subscribed
    # Szigorú hozzáférés-ellenőrzés: Csak hitelesített rendszergazdák számára engedélyezett
    unless current_user&.admin?
      reject
      return
    end

    stream_from STREAM_NAME

    # Csatlakozáskor azonnal átadjuk a legfrissebb pillanatnyi telemetriát
    metrics = ServerMetricsService.collect_metrics
    transmit(metrics)
  end

  def unsubscribed
    # Kapcsolat bontása - tiszta lezárás
    stop_all_streams
  end

  # Kliensoldali manuális vagy periodikus lekérés kezelése
  def refresh(_data = {})
    return unless current_user&.admin?

    metrics = ServerMetricsService.collect_metrics
    transmit(metrics)
  end

  # Osztályszintű szétküldés az összes csatlakozott adminisztrátornak
  def self.broadcast_metrics
    metrics = ServerMetricsService.collect_metrics
    ActionCable.server.broadcast(STREAM_NAME, metrics)
    metrics
  end
end

