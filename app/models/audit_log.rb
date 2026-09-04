# ==============================================================================
# Bánk's Repository - Biztonsági Audit Napló Modell (AuditLog)
# ==============================================================================
# Megmásíthatatlan biztonsági napló a platform szintű kritikus eseményekhez.
# Rögzíti az adminisztrátori döntéseket, szerepkör-módosításokat, felfüggesztéseket
# és fiók-zárolásokat, strukturált metaadatokkal (JSON).
# ==============================================================================

class AuditLog < ApplicationRecord
  # Nem engedélyezzük a naplóbejegyzések módosítását (Append-only)
  def readonly?
    persisted?
  end

  belongs_to :actor, class_name: "User", foreign_key: :actor_user_id, optional: true
  belongs_to :target_user, class_name: "User", foreign_key: :target_user_id, optional: true

  validates :action, presence: true
  validates :created_at, presence: true

  # Rögzítő segédmetódus a vezérlők és szolgáltatások számára
  def self.log!(action:, actor: nil, target: nil, resource: nil, metadata: {}, request: nil)
    create!(
      action: action.to_s,
      actor: actor,
      target_user: target,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      metadata_payload: metadata,
      ip_address: request&.remote_ip,
      created_at: Time.current
    )
  end
end

