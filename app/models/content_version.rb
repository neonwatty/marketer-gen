class ContentVersion < ApplicationRecord
  belongs_to :content_repository
  belongs_to :author, class_name: "User"

  validates :body, presence: true
  validates :version_number, presence: true, uniqueness: { scope: :content_repository_id }
  validates :commit_hash, presence: true, uniqueness: true

  scope :by_repository, ->(repo_id) { where(content_repository_id: repo_id) }
  scope :ordered, -> { order(:version_number) }
  scope :by_author, ->(author_id) { where(author_id: author_id) }

  before_create :generate_commit_hash
  after_create :update_repository_file_hash

  def previous_version
    self.class.where(content_repository: content_repository)
              .where("version_number < ?", version_number)
              .order(:version_number)
              .last
  end

  def next_version
    self.class.where(content_repository: content_repository)
              .where("version_number > ?", version_number)
              .order(:version_number)
              .first
  end

  def is_latest?
    content_repository.current_version == self
  end

  def diff_from_previous
    return nil unless previous_version

    {
      additions: calculate_additions,
      deletions: calculate_deletions,
      changes: calculate_line_changes
    }
  end

  def revert_to!
    content_repository.update!(
      body: body,
      updated_at: Time.current
    )
    content_repository.create_version!(
      body: body,
      author: Current.user,
      commit_message: "Reverted to version #{version_number}"
    )
  end

  private

  def generate_commit_hash
    hash_content = [
      content_repository_id,
      version_number,
      body,
      author_id,
      Time.current.to_i
    ].join("|")

    self.commit_hash = Digest::SHA256.hexdigest(hash_content)
  end

  def update_repository_file_hash
    content_repository.update_column(:file_hash, commit_hash)
  end

  def calculate_additions
    return [] unless previous_version

    current_lines = body.split("\n")
    previous_lines = previous_version.body.split("\n")

    current_lines - previous_lines
  end

  def calculate_deletions
    return [] unless previous_version

    current_lines = body.split("\n")
    previous_lines = previous_version.body.split("\n")

    previous_lines - current_lines
  end

  def calculate_line_changes
    return [] unless previous_version

    current_lines = body.split("\n")
    previous_lines = previous_version.body.split("\n")

    changes = []
    max_lines = [ current_lines.length, previous_lines.length ].max

    (0...max_lines).each do |i|
      current_line = current_lines[i]
      previous_line = previous_lines[i]

      if current_line != previous_line
        changes << {
          line: i + 1,
          old: previous_line,
          new: current_line
        }
      end
    end

    changes
  end
end
