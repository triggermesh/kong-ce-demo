bridge "ibm_mq_multiple_routes" {}

// CloudEvents synchronous routing based on the Type attribute
router content_based "dispatcher" {
  route {
    attributes = {
      type: "io.triggermesh.flow.foo"
    }
    to = transformer.foo
  }
  
  route {
    attributes = {
      type: "io.triggermesh.flow.bar"
    }
    to = transformer.bar
  }

  synchronous {
    response_timeout = "20s"
  }
}

// Transformation for CloudEvents of "io.triggermesh.flow.foo" type
transformer bumblebee "foo" {
  context {
    operation "store" {
      path {
        key = "$originalType"
        value = "type"
      }
    }
    operation "add" {
      path {
        key = "type"
        value = "io.triggermesh.bumblebee.foo"
      }
    }
  }
  data {
    operation "shift" {
      path {
        key = "name:client.name"
      }
    }
    operation "add" {
      path {
        key = "kongType"
        value = "$originalType"
      }
    }
  }
  
  to = target.mq_input_channel
}

// Transformation for CloudEvents of "io.triggermesh.flow.bar" type
transformer function "bar" {
  runtime = "python"
  response_is_event = true

  code = <<-EOF
    def main(event, context):
      return {
        "type" : "io.triggermesh.klr.serialized.bar",
        "datacontenttype" : "application/json",
        "correlationid": context.ce["correlationid"],
        "data" : {
          "path": "/bar",
          "client" : event["name"]
        }
      }
  EOF

  to = target.mq_input_channel
}

// Input channel IBM MQ Target
target ibmmq "mq_input_channel" {
  connection_name = "ibm-mq.default.svc.cluster.local(1414)"
  credentials = secret_name("ibm-mq-secret")
  queue_manager = "QM1"
  queue_name = "DEV.QUEUE.1"
  channel_name = "DEV.APP.SVRCONN"
  reply_to {
    queue = "DEV.QUEUE.2"
  }
}

// Output channel IBM MQ Source
// Events are sinked to the router defined at the top of the file
source ibmmq "mq_output_channel" {
  connection_name = "ibm-mq.default.svc.cluster.local(1414)"
  credentials = secret_name("ibm-mq-secret")
  queue_manager = "QM1"
  queue_name = "DEV.QUEUE.2"
  channel_name = "DEV.APP.SVRCONN"

  to = router.dispatcher
}
