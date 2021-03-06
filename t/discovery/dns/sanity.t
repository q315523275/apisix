#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

master_on();
repeat_each(1);
no_root_location();
no_shuffle();

add_block_preprocessor(sub {
    my ($block) = @_;

    if (!$block->yaml_config) {
        my $yaml_config = <<_EOC_;
apisix:
    node_listen: 1984
    config_center: yaml
    enable_admin: false
discovery:                        # service discovery center
    dns:
        servers:
            - "127.0.0.1:1053"
_EOC_

        $block->set_value("yaml_config", $yaml_config);
    }

    if ($block->apisix_yaml) {
        my $upstream = <<_EOC_;
routes:
  -
    id: 1
    uris:
        - /hello
    upstream_id: 1
#END
_EOC_

        $block->set_value("apisix_yaml", $block->apisix_yaml . $upstream);
    }

    if (!$block->request) {
        $block->set_value("request", "GET /hello");
    }

    if ((!defined $block->error_log) && (!defined $block->no_error_log)) {
        $block->set_value("no_error_log", "[error]");
    }
});

run_tests();

__DATA__

=== TEST 1: default port to 53
--- log_level: debug
--- yaml_config
apisix:
    node_listen: 1984
    config_center: yaml
    enable_admin: false
discovery:                        # service discovery center
    dns:
        servers:
            - "127.0.0.1"
--- apisix_yaml
upstreams:
    - service_name: sd.test.local
      discovery_type: dns
      type: roundrobin
      id: 1
--- error_code: 503
--- error_log
connect to 127.0.0.1:53



=== TEST 2: A
--- apisix_yaml
upstreams:
    - service_name: "sd.test.local:1980"
      discovery_type: dns
      type: roundrobin
      id: 1
--- grep_error_log eval
qr/upstream nodes: \{[^}]+\}/
--- grep_error_log_out eval
qr/upstream nodes: \{("127.0.0.1:1980":1,"127.0.0.2:1980":1|"127.0.0.2:1980":1,"127.0.0.1:1980":1)\}/
--- response_body
hello world



=== TEST 3: AAAA
--- listen_ipv6
--- apisix_yaml
upstreams:
    - service_name: "ipv6.sd.test.local:1980"
      discovery_type: dns
      type: roundrobin
      id: 1
--- response_body
hello world



=== TEST 4: prefer A to AAAA
--- listen_ipv6
--- apisix_yaml
upstreams:
    - service_name: "mix.sd.test.local:1980"
      discovery_type: dns
      type: roundrobin
      id: 1
--- response_body
hello world



=== TEST 5: no /etc/hosts
--- apisix_yaml
upstreams:
    - service_name: test.com
      discovery_type: dns
      type: roundrobin
      id: 1
--- error_log
failed to query the DNS server
--- error_code: 503



=== TEST 6: no /etc/resolv.conf
--- yaml_config
apisix:
    node_listen: 1984
    config_center: yaml
    enable_admin: false
    enable_resolv_search_option: false
discovery:                        # service discovery center
    dns:
        servers:
            - "127.0.0.1:1053"
--- apisix_yaml
upstreams:
    - service_name: apisix
      discovery_type: dns
      type: roundrobin
      id: 1
--- error_log
failed to query the DNS server
--- error_code: 503



=== TEST 7: bad discovery configuration
--- yaml_config
apisix:
    node_listen: 1984
    config_center: yaml
    enable_admin: false
    enable_resolv_search_option: false
discovery:                        # service discovery center
    dns:
        servers: "127.0.0.1:1053"
--- apisix_yaml
upstreams:
    - service_name: apisix
      discovery_type: dns
      type: roundrobin
      id: 1
--- error_log
invalid dns discovery configuration
--- error_code: 500
