# use a shared lock and credits_remaining
@lock = Mutex.new
@credits_remaining = 40
@shopify_url = ENV["SHOPIFY_URL"]

# Sends a request to Shopify, blocking until credits are available
def self.request(method, path, params={})
  params[:headers] = {"Content-Type" => "application/json"}

  # wait for a credit
  wait_for_credits

  # send the request
  response = Excon.new(File.join(@shopify_url, path), params).request(method: method)

  # set the credits remaining from the response
  set_credits_remaining_from_response(response)
  response
end

# Wait for API credits to be available
def self.wait_for_credits
  while !obtain_credit
    puts "Waiting 10 seconds for a credit"
    sleep(10)
  end
end

# Set the current credits remaining from the response
#
# Returns used, total amounts
def self.set_credits_remaining_from_response(response)
  used, total = parse_credit_limit_from_response(response)
  @lock.synchronize do
    @credits_remaining = total - used
    puts "Setting credits from response - credits remaining: #{@credits_remaining}"
  end
end
