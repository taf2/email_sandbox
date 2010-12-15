EmailSandbox::Application.routes.draw do
  resources :emails, :only => [:show, :index] do
    collection do
      post :check
    end
  end
end
