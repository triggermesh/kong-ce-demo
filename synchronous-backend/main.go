/*
 * Copyright (c) IBM Corporation 2019
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0, which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/caarlos0/env"
	"github.com/ibm-messaging/mq-golang-jms20/jms20subset"
	"github.com/ibm-messaging/mq-golang-jms20/mqjms"
)

type CloudEvent struct {
	Data    map[string]interface{} `json:"data"`
	Context map[string]interface{} `json:"-"`
}

/*
 * Simulate application replying to a message
 */
func main() {
	type config struct {
		InputQueue         string `env:"MQ_INPUT_QUEUE" envDefault:"DEV.QUEUE.1"`
		ConnectionInfoJSON string `env:"MQ_CONNECTION_INFO" envDefault:"/opt/mqm/config/connection_info.json"`
		APIKeyJSON         string `env:"MQ_API_KEY" envDefault:"/opt/mqm/config/applicationApiKey.json"`
	}

	cfg := config{}
	env.Parse(&cfg)

	// Loads CF parameters from connection_info.json and applicationApiKey.json in the Downloads directory
	cf, err := mqjms.CreateConnectionFactoryFromJSON(cfg.ConnectionInfoJSON, cfg.APIKeyJSON)
	if err != nil {
		panic(err)
	}

	context, err := cf.CreateContext()
	if err != nil {
		panic(err)
	}
	if context != nil {
		defer context.Close()
	}

	requestQueue := context.CreateQueue(cfg.InputQueue)

	// Receive the request message.
	requestConsumer, err := context.CreateConsumer(requestQueue)
	if err != nil {
		panic(err)
	}
	if requestConsumer != nil {
		defer requestConsumer.Close()
	}

	fmt.Println("Starting receiver")

	for {
		fmt.Println("waiting...")
		reqMsg, err := requestConsumer.Receive(int32(time.Second))
		if err != nil {
			fmt.Printf("Consumer receive error: %v\n", err)
			return
		}
		if reqMsg == nil {
			fmt.Println("empty message, skipping")
			continue
		}

		var data string
		switch msg := reqMsg.(type) {
		case jms20subset.TextMessage:
			data = *msg.GetText()
		default:
			fmt.Printf("Received message format error\n")
			continue
		}

		fmt.Printf("message received: %s\n", string(data))

		var ce CloudEvent
		if err := json.Unmarshal([]byte(data), &ce); err != nil {
			fmt.Printf("Failed to unmarshal data: %v\n", err)
			continue
		}

		if ce.Data != nil {
			ce.Data["Backend"] = "System Of Record"
		}

		newData, jerr := json.Marshal(ce)
		if jerr != nil {
			fmt.Printf("Failed to marshal data: %v\n", err)
			continue
		}

		replyMsg := context.CreateBytesMessageWithBytes(newData)
		replyMsg.SetJMSCorrelationID(reqMsg.GetJMSCorrelationID())

		// Send the reply message back to the original application
		if err := context.CreateProducer().Send(reqMsg.GetJMSReplyTo(), replyMsg); err != nil {
			fmt.Printf("Failed to send the message: %v\n", err)
			continue
		}
		fmt.Println("message sent")
	}
}
