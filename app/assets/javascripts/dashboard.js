MinionPoller = {
  poll: function() {
    this.request();
    return setInterval(this.request, 5000);
  },

  stateWeight: function(state) {
    switch (state) {
      case 'failed':
        return 3;
      case 'update':
        return 2;
      case 'pending':
        return 1;
      // applied, not_applied
      default:
        return 0;
    }
  },

  sortMinions: function(minions) {
    minions.sort(function(a, b) {
      return MinionPoller.stateWeight(b.highstate)- MinionPoller.stateWeight(a.highstate);
    });
  },

  request: function() {
    $.ajax({
      url: $('.nodes-container').data('url'),
      dataType: "json",
      cache: false,
      success: function(data) {
        var rendered = "";
        MinionPoller.selectedMasters = $("input[name='roles[master][]']:checked").map(function() {
          return parseInt($( this ).val());
        }).get();

        // In discovery, the minions to be rendered are unassigned, while on the
        // dashboard we don't want to render unassigned minions but we still
        // want to account for them.
        var minions = data.assigned_minions || [];
        var unassignedMinions = data.unassigned_minions || [];
        if (MinionPoller.renderMode == "discovery") {
          minions = minions.concat(unassignedMinions);
        } else {
          MinionPoller.sortMinions(minions);
        }

        for (i = 0; i < minions.length; i++) {
          if (MinionPoller.renderMode == "discovery") {
            rendered += MinionPoller.renderDiscovery(minions[i]);
          } else {
            rendered += MinionPoller.render(minions[i]);
          }
        }
        $(".nodes-container tbody").html(rendered);

        // disable bootstrap button if there are no minions
        if (minions.length == 0) {
          $("#bootstrap").prop('disabled', true);
        } else {
          $("#bootstrap").prop('disabled', false);
        }

        $('.assigned-count').text(minions.length);
        $('.master-count').text(MinionPoller.selectedMasters.length);

        if (unassignedMinions.length > 0) {
          if ($("#node-count").length > 0) {
            $("#node-count").text(unassignedMinions.length + " nodes found");
          } else {
            $('.unassigned-count').text(unassignedMinions.length);
          }
        } else {
          $('.unassigned-count').text(0);
        }
      }
    });
  },

  render: function(minion) {
    var statusHtml;
    var checked;
    var masterHtml;

    switch(minion.highstate) {
      case "not_applied":
        statusHtml = '<i class="fa fa-circle-o text-success fa-2x" aria-hidden="true"></i>';
        break;
      case "pending":
        statusHtml = '\
          <span class="fa-stack" aria-hidden="true">\
            <i class="fa fa-circle fa-stack-2x text-success" aria-hidden="true"></i>\
            <i class="fa fa-refresh fa-stack-1x fa-spin fa-inverse" aria-hidden="true"></i>\
          </span>';
        break;
      case "failed":
        statusHtml = '<i class="fa fa-times-circle text-danger fa-2x" aria-hidden="true"></i>';
        break;
      case "applied":
        statusHtml = '<i class="fa fa-check-circle-o text-success fa-2x" aria-hidden="true"></i>';
        break;
    }

    if ((MinionPoller.selectedMasters && MinionPoller.selectedMasters.indexOf(minion.id) != -1) || minion.role == "master") {
      checked =  "checked";
    } else {
      checked = '';
    }
    masterHtml = '<input name="roles[master][]" id="roles_master_' + minion.id +
      '" value="' + minion.id + '" type="radio" disabled="" ' + checked + '>';

    return "\
      <tr> \
        <th>" + minion.id +  "</th>\
        <td class='text-center'>" + statusHtml +  "</td>\
        <td>" + minion.fqdn +  "</td>\
        <td>" + (minion.role || '') +  "</td>\
        <td class='text-center'>" + masterHtml + "</td>\
      </tr>";
  },

  renderDiscovery: function(minion) {
    var masterHtml;
    var checked;

    if (MinionPoller.selectedMasters && MinionPoller.selectedMasters.indexOf(minion.id) != -1) {
      checked = "checked";
    } else {
      checked = '';
    }
    masterHtml = '<input name="roles[master][]" id="roles_master_' + minion.id +
      '" value="' + minion.id + '" type="radio" ' + checked + '>';

    return "\
      <tr> \
        <th>" + minion.id +  "</th>\
        <td>" + minion.fqdn +  "</td>\
        <td class='text-center'>" + masterHtml + "</td>\
      </tr>";
  }
};
