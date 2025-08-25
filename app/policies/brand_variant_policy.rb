# frozen_string_literal: true

class BrandVariantPolicy < ApplicationPolicy
  # Basic CRUD permissions
  def index?
    user.present?
  end

  def show?
    user.present? && record.user == user
  end

  def create?
    user.present? && record.user == user && record.brand_identity.user == user
  end

  def update?
    user.present? && record.user == user && !record.archived?
  end

  def destroy?
    user.present? && record.user == user && record.draft?
  end

  # Status management permissions
  def activate?
    user.present? && record.user == user && (record.draft? || record.testing?)
  end

  def deactivate?
    user.present? && record.user == user && record.active?
  end

  def archive?
    user.present? && record.user == user && !record.archived?
  end

  def test?
    user.present? && record.user == user && (record.draft? || record.active?)
  end

  def duplicate?
    user.present? && record.user == user
  end

  # Content adaptation permissions
  def adapt_content?
    user.present?
  end

  def analyze_consistency?
    user.present?
  end

  def analyze_compatibility?
    user.present?
  end

  def update_effectiveness?
    user.present? && record.user == user && record.active?
  end

  # Scope for filtering records
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present?
      
      # Users can only see their own brand variants
      scope.joins(:brand_identity)
           .where(brand_identities: { user: user })
           .where(user: user)
    end
  end

  private

  # Helper method to check if user owns the brand identity
  def user_owns_brand_identity?
    record.brand_identity&.user == user
  end

  # Helper method to check if variant can be modified
  def variant_modifiable?
    !record.archived?
  end

  # Helper method to check if variant is in a testable state
  def variant_testable?
    record.draft? || record.active?
  end
end