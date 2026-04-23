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
  end

  def admin_unit_abilities(user)
    org_id = user.organization_id

    can :manage, ContactPoint,       organization_id: org_id
    can :manage, Meter,              organization_id: org_id
    can :manage, Personnel,          contact_point: { organization_id: org_id }
    can :manage, MeterReading,       meter: { organization_id: org_id }
    can :manage, MonthlyCalculation, contact_point: { organization_id: org_id }

    can :read, UnitConfig, organization_id: org_id
    can :update_unit_config,        UnitConfig, organization_id: org_id
    can :update_electricity_supply, UnitConfig, organization_id: org_id

    can :read, MonthlyPeriod
    can :read, RankQuota
  end

  def commander_abilities(user)
    org_id = user.organization_id

    can :read, ContactPoint,       organization_id: org_id
    can :read, Meter,              organization_id: org_id
    can :read, Personnel,          contact_point: { organization_id: org_id }
    can :read, MeterReading,       meter: { organization_id: org_id }
    can :read, MonthlyCalculation, contact_point: { organization_id: org_id }
    can :read, UnitConfig,         organization_id: org_id

    can :read, MonthlyPeriod
    can :read, RankQuota
  end

  def tech_abilities
    can :manage, User
  end
end
