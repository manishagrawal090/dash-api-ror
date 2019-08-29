class User < ApplicationRecord
  rolify
  enum status: [ :active, :inactive ]
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attr_accessor :avatar_base64,:avatar_delete
  before_validation :set_image
  before_update :delete_avatar
  after_create :assign_default_role
  
  has_attached_file :avatar, styles: { medium: '300x300>', thumb: '100x100>' }, default_url: '/missing.jpg',
                     path: ':rails_root/public/system/users/avatars/:id/:style_:filename',
                    :url  => '/system/users/avatars/:id/:style_:filename'

  validates_attachment_content_type :avatar, content_type: /\Aimage\/.*\z/


  def set_image
    if avatar_base64.present?
      file = Paperclip.io_adapters.for(avatar_base64)
      file.original_filename = 'avatar_name.jpg'
      self.avatar = file
    end
  end

  def assign_default_role
    self.add_role(:user) if self.roles.blank?
  end

  def delete_avatar
    if avatar_base64.nil?
      self.avatar.clear if avatar_delete == 'true'
    end
  end

  def remove_column_merge
    attributes
      .merge('avatar' => Rails.application.config.root_url.chomp('/') + self.avatar.url,'roles' => self.roles.pluck(:name))
      .except('encrypted_password','reset_password_token','reset_password_sent_at','remember_created_at','created_at','updated_at',
              'avatar_file_name','avatar_content_type','avatar_file_size','avatar_updated_at')
  end
end
