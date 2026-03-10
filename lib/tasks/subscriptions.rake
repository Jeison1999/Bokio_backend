namespace :subscriptions do
  desc "Suspend businesses with expired subscriptions"
  task suspend_expired: :environment do
    puts "Checking for expired subscriptions..."
    
    expired_count = 0
    
    Business.active.includes(:subscription).find_each do |business|
      next unless business.subscription
      
      if business.subscription.expired?
        puts "  Suspending: #{business.name} (expired on #{business.subscription.expires_at})"
        business.suspend_for_non_payment!
        expired_count += 1
      end
    end
    
    puts "\n✅ Process completed!"
    puts "   Businesses suspended: #{expired_count}"
  end
  
  desc "List businesses with subscriptions expiring soon (within 7 days)"
  task expiring_soon: :environment do
    puts "Checking for subscriptions expiring in the next 7 days..."
    
    expiring_date = 7.days.from_now
    
    Subscription.active.where('expires_at <= ? AND expires_at > ?', expiring_date, Time.current).find_each do |subscription|
      business = subscription.business
      days_left = ((subscription.expires_at - Time.current) / 1.day).ceil
      
      puts "  ⚠️  #{business.name}"
      puts "      Plan: #{subscription.plan}"
      puts "      Expires: #{subscription.expires_at.strftime('%Y-%m-%d')} (#{days_left} days left)"
      puts "      Owner: #{business.owner.email}"
      puts ""
    end
  end
  
  desc "Reactivate a suspended business (provide BUSINESS_ID)"
  task reactivate: :environment do
    business_id = ENV['BUSINESS_ID']
    
    unless business_id
      puts "❌ Error: Please provide BUSINESS_ID"
      puts "   Usage: rake subscriptions:reactivate BUSINESS_ID=123"
      exit 1
    end
    
    business = Business.find_by(id: business_id)
    
    unless business
      puts "❌ Error: Business not found"
      exit 1
    end
    
    unless business.subscription
      puts "❌ Error: Business has no subscription"
      exit 1
    end
    
    # Reactivar suscripción por 1 mes
    business.subscription.update(
      status: :active,
      expires_at: 1.month.from_now
    )
    business.update(active: true)
    
    puts "✅ Business reactivated successfully!"
    puts "   Name: #{business.name}"
    puts "   New expiration date: #{business.subscription.expires_at.strftime('%Y-%m-%d')}"
  end
end
