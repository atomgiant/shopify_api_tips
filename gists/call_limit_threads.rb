# Run 42 threads to hit the call limit
42.times.each do
  Thread.new { Shopify.get_product(1234567890) }
end
