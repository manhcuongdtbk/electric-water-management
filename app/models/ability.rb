class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    case user.role.to_sym
    when :admin_level1 then admin_level1_abilities
    when :admin_unit   then admin_unit_abilities(user)
    when :commander    then commander_abilities(user)
    when :tech         then tech_abilities
    end
  end

  private

  def admin_level1_abilities
    can :manage, :all
    # Unit config section is for admin_unit only — admin_level1 manages via the
    # division section instead.
    cannot :update_unit_config, UnitConfig
    # Backup/restore is tech-only.
    cannot :manage, :backup
  end

  def admin_unit_abilities(user)
    org_id = user.organization_id

    can :manage, ContactPoint,       organization_id: org_id
    can :manage, Meter,              organization_id: org_id
    can :manage, Personnel,          contact_point: { organization_id: org_id }
    can :manage, MeterReading,       meter: { organization_id: org_id }
    can :read,        MonthlyCalculation, contact_point: { organization_id: org_id }
    can :recalculate, MonthlyCalculation, contact_point: { organization_id: org_id }

    can :read, UnitConfig, organization_id: org_id
    can :update_unit_config, UnitConfig, organization_id: org_id

    can :read, MainMeter,        organizations: { id: org_id }
    can :read, MainMeterReading, main_meter: { organizations: { id: org_id } }

    can :manage, ContactPointGroup,       organization_id: org_id
    can :manage, ContactPointGroupMembership, contact_point_group: { organization_id: org_id }

    can :manage, WorkGroup, owner_organization_id: org_id

    can :read, MonthlyPeriod
    can :read, RankQuota

    # Zone-manager: admin_unit at zone.manager_organization manages shared zone
    # infra (công tơ tổng, trạm bơm, phân bổ bơm). The `if any?` guard keeps the
    # rule literally absent for non-zone-managers so class-level checks the
    # sidebar uses (e.g. `can? :manage, PumpStation`) return false for them.
    managed_zone_ids = Zone.where(manager_organization_id: org_id).pluck(:id)
    if managed_zone_ids.any?
      can :read,   Zone,                  id: managed_zone_ids
      can :manage, MainMeter,             zone_id: managed_zone_ids
      can :manage, MainMeterReading,      main_meter: { zone_id: managed_zone_ids }
      can :manage, PumpStation,           zone_id: managed_zone_ids
      can :manage, PumpStationAssignment, pump_station: { zone_id: managed_zone_ids }
    end
  end

  def commander_abilities(user)
    org_id = user.organization_id

    can :read, ContactPoint,       organization_id: org_id
    can :read, Meter,              organization_id: org_id
    can :read, Personnel,          contact_point: { organization_id: org_id }
    can :read, MeterReading,       meter: { organization_id: org_id }
    can :read, MonthlyCalculation, contact_point: { organization_id: org_id }
    can :read, UnitConfig,         organization_id: org_id

    can :read, MainMeter,        organizations: { id: org_id }
    can :read, MainMeterReading, main_meter: { organizations: { id: org_id } }

    can :read, ContactPointGroup,       organization_id: org_id
    can :read, ContactPointGroupMembership, contact_point_group: { organization_id: org_id }

    can :read, WorkGroup, owner_organization_id: org_id

    can :read, MonthlyPeriod
    can :read, RankQuota

    can :read, Zone, id: user.organization&.zone_id
  end

  def tech_abilities
    can :manage, User
    can :read, :audit_log
    can :manage, :backup
  end
end
