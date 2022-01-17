bridge "ibm_mq_multiple_routes" {}

// Input channel IBM MQ Target
target ibmmq "input_channel" {
  connection_name = "ibm-mq.default.svc.cluster.local(1414)"
  credentials = secret_name("ibm-mq-secret")
  queue_manager = "QM1"
  queue_name = "DEV.QUEUE.1"
  channel_name = "DEV.APP.SVRCONN"
  reply_to {
    queue = "DEV.QUEUE.2"
  }
  synchronous {
    response_timeout = "20s"
  }
}

// Output channel IBM MQ Source
// Events are sinked to the router defined at the top of the file
source ibmmq "output_channel" {
  connection_name = "ibm-mq.default.svc.cluster.local(1414)"
  credentials = secret_name("ibm-mq-secret")
  queue_manager = "QM1"
  queue_name = "DEV.QUEUE.2"
  channel_name = "DEV.APP.SVRCONN"

  to = target.input_channel
}
