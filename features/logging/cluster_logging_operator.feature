@clusterlogging
Feature: cluster-logging-operator related test

  # @author qitang@redhat.com
  # @case_id OCP-19875
  @admin
  @destructive
  @commonlogging
  Scenario: Fluentd provide Prometheus metrics
    Given evaluation of `cluster_logging('instance').collection_type` is stored in the :collection_type clipboard
    Given a pod becomes ready with labels:
      | component=<%= cb.collection_type %> |
    And I execute on the pod:
      | bash                                    |
      | -c                                      |
      | curl -k https://localhost:24231/metrics |
    Then the step should succeed
    And the expression should be true> @result[:response].include? (cb.collection_type == "fluentd" ? "fluentd_output_status_buffer_total_bytes": "rsyslog_action_processed")

  # @author qitang@redhat.com
  # @case_id OCP-21333
  @admin
  @destructive
  @commonlogging
  Scenario: ServiceMonitor Object for collector is deployed along with cluster logging
    Given I wait for the "fluentd" service_monitor to appear
    Given the expression should be true> service_monitor('fluentd').service_monitor_endpoint_spec(server_name: "fluentd.openshift-logging.svc").port == "metrics"
    And the expression should be true> service_monitor('fluentd').service_monitor_endpoint_spec(server_name: "fluentd.openshift-logging.svc").path == "/metrics"
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                            |
      | query | fluentd_output_status_buffer_queue_length |
    Then the step should succeed
    And the expression should be true>  @result[:parsed]['data']['result'][0]['value']
    """

  # @author qitang@redhat.com
  # @case_id OCP-21907
  @admin
  @destructive
  Scenario: Deploy elasticsearch-operator via OLM using CLI
    Given logging operators are installed successfully

  # @author qitang@redhat.com
  # @case_id OCP-22492
  @admin
  @destructive
  Scenario: Scale Elasticsearch nodes by nodeCount 2->3->4 in clusterlogging
    Given I delete the clusterlogging instance
    Then the step should succeed
    And I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/logging/clusterlogging/scalebase.yaml |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given I delete the clusterlogging instance
    """
    # Given admin ensures "instance" cluster_logging is deleted from the "openshift-logging" project after scenario
    And I wait for the "elasticsearch" elasticsearches to appear
    And the expression should be true> cluster_logging('instance').logstore_node_count == 2
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['nodeCount'] == 2
    Given evaluation of `elasticsearch('elasticsearch').nodes[0]['genUUID']` is stored in the :gen_uuid_1 clipboard
    Then I wait for the "elasticsearch-cdm-<%= cb.gen_uuid_1 %>-1" deployment to appear
    And I wait for the "elasticsearch-cdm-<%= cb.gen_uuid_1 %>-2" deployment to appear
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":3}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_node_count == 3
    Given I wait for the steps to pass:
    """
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['nodeCount'] == 3
    """
    And I wait for the "elasticsearch-cdm-<%= cb.gen_uuid_1%>-3" deployment to appear
    When I run the :patch client command with:
      | resource      | clusterlogging                                          |
      | resource_name | instance                                                |
      | p             | {"spec":{"logStore":{"elasticsearch":{"nodeCount":4}}}} |
      | type          | merge                                                   |
    Then the step should succeed
    And the expression should be true> cluster_logging('instance').logstore_node_count == 4
    Given I wait for the steps to pass:
    """
    And the expression should be true> elasticsearch('elasticsearch').nodes[0]['nodeCount'] + elasticsearch('elasticsearch').nodes[1]['nodeCount'] == 4
    """
    Given I wait for the steps to pass:
    """
    Given evaluation of `elasticsearch('elasticsearch').nodes[1]['genUUID']` is stored in the :gen_uuid_2 clipboard
    And the expression should be true> cb.gen_uuid_2 != nil
    """
    And I wait for the "elasticsearch-cd-<%= cb.gen_uuid_2 %>-1" deployment to appear

  # @author qitang@redhat.com
  # @case_id OCP-23738
  @admin
  @destructive
  Scenario: Fluentd alert rule: FluentdNodeDown
    Given the master version >= "4.2"
    Given I create clusterlogging instance with:
      | remove_logging_pods | true                                                                                                   |
      | crd_yaml            | <%= BushSlicer::HOME %>/testdata/logging/clusterlogging/example.yaml |
      | log_collector       | fluentd                                                                                                |
    Then the step should succeed
    Given I wait for the "fluentd" prometheus_rule to appear
    And I wait for the "fluentd" service_monitor to appear
    # make all fluentd pods down
    When I run the :patch client command with:
      | resource      | clusterlogging                                                                        |
      | resource_name | instance                                                                              |
      | p             | {"spec": {"collection": {"logs": {"fluentd":{"nodeSelector": {"logging": "test"}}}}}} |
      | type          | merge                                                                                 |
    Then the step should succeed
    And I wait up to 360 seconds for the steps to pass:
    """
    When I perform the GET prometheus rest client with:
      | path  | /api/v1/query?                      |
      | query | ALERTS{alertname="FluentdNodeDown"} |
    Then the step should succeed
    And the output should match:
      | "alertstate":"pending\|firing" |
    """ 
