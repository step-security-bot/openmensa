
OMNI_CONFIG = YAML.load_file(Rails.root.join("config","omniauth.yml"))[Rails.env]

if OMNI_CONFIG
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :github, OMNI_CONFIG['github']['key'], OMNI_CONFIG['github']['secret'] if OMNI_CONFIG['github']
    provider :twitter, OMNI_CONFIG['twitter']['key'], OMNI_CONFIG['twitter']['secret'] if OMNI_CONFIG['twitter']
  end
end
