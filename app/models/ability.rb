# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    if user.force_password_change?
      can :update, User, id: user.id
      return
    end

    case user.role.to_sym
    when :technician   then technician_abilities(user)
    when :system_admin then system_admin_abilities(user)
    when :unit_admin   then unit_admin_abilities(user)
    when :commander    then commander_abilities(user)
    end
  end

  private

  def technician_abilities(_user)
    can :manage, User
    can :read, Unit
    can :read, PaperTrail::Version
    can :manage, Backup
  end

  def system_admin_abilities(_user)
    [Unit, ContactPoint, Meter, MainMeter, Block, Group,
     Period, Rank, PumpAllocation,
     MeterReading, MainMeterReading, PersonnelEntry,
     NonEstablishmentSnapshot, UnitConfig, OtherDeduction, Calculation
    ].each { |m| can :manage, m }
    can :manage, Zone, discarded_at: nil
    can :recalculate, Calculation

    can :manage, User
    cannot [:create, :update, :destroy], User, role: "technician"

    can :read, PaperTrail::Version
  end

  def unit_admin_abilities(user)
    uid = user.unit_id
    managed_zone_ids = Zone.kept.where(manager_unit_id: uid).pluck(:id)

    can :read, Unit, id: uid
    can [:create, :read, :update, :destroy], ContactPoint, unit_id: uid
    can [:create, :read, :update, :destroy], Meter, contact_point: { unit_id: uid }
    can [:create, :read, :update, :destroy], Block, unit_id: uid
    can [:create, :read, :update, :destroy], Group, unit_id: uid
    can [:read, :update], MeterReading, meter: { contact_point: { unit_id: uid } }
    can [:read, :update], PersonnelEntry, contact_point: { unit_id: uid }
    can [:read, :update], OtherDeduction, contact_point: { unit_id: uid }
    can [:read, :update], UnitConfig, unit_id: uid
    can :read, Calculation, contact_point: { unit_id: uid }
    can :recalculate, Calculation, contact_point: { unit_id: uid }
    can :read, Period
    can :read, Rank

    return if managed_zone_ids.empty?

    can :read, Zone, id: managed_zone_ids
    can :read, MainMeter, zone_id: managed_zone_ids
    can [:create, :read, :update, :destroy], MainMeterReading, main_meter: { zone_id: managed_zone_ids }
    can :read, Block, unit: { zone_id: managed_zone_ids }
    can :read, Group, unit: { zone_id: managed_zone_ids }
    can [:create, :read, :update, :destroy], ContactPoint, zone_id: managed_zone_ids
    can [:create, :read, :update, :destroy], Meter, contact_point: { zone_id: managed_zone_ids }
    can [:create, :read, :update, :destroy], PumpAllocation, zone_id: managed_zone_ids
    can [:read, :update], MeterReading,
      meter: { contact_point: { zone_id: managed_zone_ids } }
    can [:read, :update], PersonnelEntry,
      contact_point: { zone_id: managed_zone_ids, contact_point_type: "residential" }
    can [:read, :update], NonEstablishmentSnapshot,
      contact_point: { zone_id: managed_zone_ids }
    can [:read, :update], OtherDeduction,
      contact_point: { zone_id: managed_zone_ids, contact_point_type: "residential" }
    can :read, Calculation, contact_point: { zone_id: managed_zone_ids }
    can :recalculate, Calculation, contact_point: { zone_id: managed_zone_ids }
  end

  def commander_abilities(user)
    uid = user.unit_id
    managed_zone_ids = Zone.kept.where(manager_unit_id: uid).pluck(:id)

    can :read, Unit, id: uid
    can :read, ContactPoint, unit_id: uid
    can :read, Meter, contact_point: { unit_id: uid }
    can :read, Block, unit_id: uid
    can :read, Group, unit_id: uid
    can :read, MeterReading, meter: { contact_point: { unit_id: uid } }
    can :read, PersonnelEntry, contact_point: { unit_id: uid }
    can :read, OtherDeduction, contact_point: { unit_id: uid }
    can :read, UnitConfig, unit_id: uid
    can :read, Calculation, contact_point: { unit_id: uid }
    can :read, Period
    can :read, Rank

    return if managed_zone_ids.empty?

    can :read, Zone, id: managed_zone_ids
    can :read, MainMeter, zone_id: managed_zone_ids
    can :read, MainMeterReading, main_meter: { zone_id: managed_zone_ids }
    can :read, Block, unit: { zone_id: managed_zone_ids }
    can :read, Group, unit: { zone_id: managed_zone_ids }
    can :read, ContactPoint, zone_id: managed_zone_ids
    can :read, Meter, contact_point: { zone_id: managed_zone_ids }
    can :read, PumpAllocation, zone_id: managed_zone_ids
    can :read, MeterReading, meter: { contact_point: { zone_id: managed_zone_ids } }
    can :read, PersonnelEntry, contact_point: { zone_id: managed_zone_ids }
    can :read, NonEstablishmentSnapshot, contact_point: { zone_id: managed_zone_ids }
    can :read, OtherDeduction, contact_point: { zone_id: managed_zone_ids }
    can :read, Calculation, contact_point: { zone_id: managed_zone_ids }
  end
end
