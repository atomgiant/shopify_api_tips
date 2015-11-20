class Shopify

  @lock = Mutex.new
  @credits_remaining = 40
  @shopify_url = ENV["SHOPIFY_URL"]

  # Get a product
  def self.get_product(id)
    result = request(:get, "products/#{id}.json")
    result['product']
  end

  def self.get_products_id_title
    request(:get, "products.json?fields=id,title")
  end

  def self.update_inventory(id, vid_quantities)
    variants = vid_quantities.map do |vid, qty|
      { "id" => vid, "inventory_quantity" => qty }
    end
    data = {
      "product" => {
        "variants" => variants
      }
    }
    request(:put, "products/#{id}.json", body: data.to_json)
  end

  def self.set_product_metafield_map(id, namespace, key, map)
    # convert the map to JSON so it fits in one metafield
    data = {
      "metafield" => {
        "namespace" => namespace,
        "key" => key,
        "value" => map.to_json,
        "value_type" => "string"
      }
    }
    request(:post, "products/#{id}/metafields.json", body: data.to_json)
  end

  # Sends a request to Shopify, blocking until credits are available
  def self.request(method, path, params={})
    params[:headers] = {"Content-Type" => "application/json"}
    wait_for_credits
    response = Excon.new(File.join(@shopify_url, path), params).request(method: method)
    set_credits_remaining_from_response(response)
    JSON.parse(response.body)
  end

  # Wait for API credits to be available
  def self.wait_for_credits
    while !obtain_credit
      # puts "Waiting 10 seconds for a credit"
      sleep(10)
    end
  end

  # Attempts to obtain an API credit
  #
  # Returns true if credit obtained, false otherwise
  def self.obtain_credit
    @lock.synchronize do
      if @credits_remaining > 5 # leave a buffer to be safe
        @credits_remaining = @credits_remaining - 1
        # puts "Obtained credit - credits remaining: #{@credits_remaining}"
        true
      else
        false
      end
    end
  end

  # Set the current credits remaining from the response
  #
  # Returns used, total amounts
  def self.set_credits_remaining_from_response(response)
    used, total = parse_credit_limit_from_response(response)
    @lock.synchronize do
      @credits_remaining = total - used
      # puts "Setting credits from response - credits remaining: #{@credits_remaining}"
    end
  end

  # Parses the used and total amounts from Shopify
  #
  # Returns used, total amounts
  def self.parse_credit_limit_from_response(response)
    call_limit = response.headers['HTTP_X_SHOPIFY_SHOP_API_CALL_LIMIT'] || "0/0"
    used, total = call_limit.split('/')
    [used.to_i, total.to_i]
  end

end
