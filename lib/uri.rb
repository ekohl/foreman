module URI
  class URI
    class Jail < Safemode::Jail
      allow :host, :port
    end
  end
end
