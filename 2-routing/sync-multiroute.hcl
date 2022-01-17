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

  to = target.sockeye
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
        "data" : {
          "path": "/bar",
          "client" : event["name"]
        }
      }
  EOF

  to = target.sockeye
}

target container "sockeye" {
  image = "docker.io/n3wscott/sockeye:v0.7.0"
  public = true
}
