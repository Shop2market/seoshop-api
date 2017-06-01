module Seoshop
  module Webhook
    def get_webhooks_count(params = {})
      response = get("webhooks/count.json", params)
      response.body ? response.body['count'].to_i : 0
    end

    def get_webhooks(params = {})
      response = get("webhooks.json", params)
      response.body ? response.body['webhooks'] || [] : []
    end

    def create_webhook(params, options = {})
      response = post("webhooks.json", { "webhook" => params })
      response.status == 201
    end

    def update_webhook(id, params)
      response = put("webhooks/#{id}.json", { "webhook" => params } )
      response.body ? response.body['webhook'] : {}
    end

    def get_webhook(id)
      response = get("webhooks/#{id}.json")
      response.body ? response.body['webhook'] : nil
    end

    def delete_webhook(id)
      response = delete("webhooks/#{id}.json")
      true
    end
  end
end
