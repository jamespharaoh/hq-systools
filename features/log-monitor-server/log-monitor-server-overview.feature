Feature: Log monitor server overview

  Background:

    Given the log monitor server config:
      """
      <log-monitor-server-config>
        <server port="${port}"/>
        <db host="${db-host}" port="${db-port}" name="${db-name}"/>
      </log-monitor-server-config>
      """

  Scenario: No events

    When I visit the overview page

    Then I should see no summaries
