import 'dart:async';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:angular2/core.dart';

import 'package:vybor/actions.dart';
import 'package:vybor/client.dart';
import 'package:vybor/firebase_client.dart';
import 'package:vybor/model.dart';

@Component(
  selector: 'vybor',
  styleUrls: const ['package:vybor/bulma.css'],
  templateUrl: 'package:vybor/template.html',
)
class VyborComponent {
  Actions actions;
  
  Client _client;

  // Structure variables

  String groupCardView;
  final String group_card_view_hidden = "GroupCardView.hidden";
  final String group_card_view_options = "GroupCardView.options";
  final String group_card_view_members = "GroupCardView.members";
  final String group_card_view_history = "GroupCardView.history";

  String modalView;
  final String modal_view_hidden = "ModalView.hidden";
  final String modal_view_manage_content = "ModalView.manageContent";
  final String modal_view_create_group = "ModalView.createGroup";
  final String modal_view_create_option = "ModalView.createPick";
  final String modal_view_show_pick = "ModalView.showPick";

  bool showMobileMenu = false;
  bool showEditGroupInput = false;

  // Content variables

  Map<String, GroupData> groups = new Map<String, GroupData>();
  GroupData group(String uid) => groups[uid];

  Map<String, OptionData> options = new Map<String, OptionData>();
  OptionData option(String uid) => options[uid];

  Map<String, PickData> picks = new Map<String, PickData>();
  PickData pick(String uid) => picks[uid];

  Map<String, UserData> users = new Map<String, UserData>();
  UserData user(String uid) => users[uid];

  GroupData theGroup;
  bool get groupSelected => theGroup != null;

  OptionData theOption;

  UserData theUser;
  bool get userSelected => theUser != null;

  String expectedGroup;
  String expectedOption;
  String expectedPick;

  bool groupCreatedByTheUser(String uid) => userSelected ? theUser.groups.contains(uid) : false;

  bool optionCreatedByTheUser(String uid) => userSelected ? theUser.options.contains(uid) : false;

  bool groupIsDeleted(String uid) => group(uid)?.deleted ?? true;
  bool groupIsVisible(String uid) => !groupIsDeleted(uid);
  List<String> visibleGroups(Iterable<String> uids) => new List<String>.from(uids.where(groupIsVisible));

  bool optionIsDeleted(String uid) => option(uid)?.deleted ?? true;
  bool optionIsVisible(String uid) => !optionIsDeleted(uid);
  List<String> visibleOptions(Iterable<String> uids) => new List<String>.from(uids.where(optionIsVisible));

  /// uids of group options.
  List<String> get groupOptions => groupSelected ? theGroup.options.asList() : new List<String>();
  Set<String> get blockedOptions => groupSelected ? new Set<String>.from(theGroup.blockedOptions) : new Set<String>();
  bool optionIsBlocked(String uid) => blockedOptions.contains(uid);

  /// uids of group members.
  List<String> get groupUsers => groupSelected ? theGroup.users.asList() : new List<String>();
  Set<String> get blockedUsers => groupSelected ? new Set<String>.from(theGroup.blockedUsers) : new Set<String>();
  bool userIdBlocked(String uid) => blockedUsers.contains(uid);

  bool optionCreatorIsBlocked(String uid) => userIdBlocked(option(uid).creator);

  /// uids of group picks.
  List<String> get groupPicks => groupSelected ? theGroup.picks.asList().reversed : new List<String>();
  String get lastPick => groupSelected && theGroup.picks.length > 0 ? theGroup.picks.last : null;
  String get lastPickedOption => lastPick != null ? pick(lastPick)?.option : null;

  VyborComponent() {
    actions = new Actions()
      ..signIn.listen(_signIn)
      ..signOut.listen(_signOut)
      ..joinGroup.listen(_joinGroup)
      ..leaveGroup.listen(_leaveGroup)
      ..createGroup.listen(_createGroup)
      ..deleteGroup.listen(_deleteGroup)
      ..updateDescription.listen(_updateDescription)
      ..disableOption.listen(_disableOption)
      ..enableOption.listen(_enableOption)
      ..disableUser.listen(_disableUser)
      ..enableUser.listen(_enableUser)
      ..createOption.listen(_createOption)
      ..deleteOption.listen(_deleteOption)
      ..createPick.listen(_createPick);

    _client = new FirebaseClient()
      ..groupDidChange.listen(_groupDidChange)
      ..optionDidChange.listen(_optionDidChange)
      ..pickDidChange.listen(_pickDidChange)
      ..userDidChange.listen(_userDidChange)
      ..theUserDidChange.listen(_theUserDidChange)
      ..theGroupDidChange.listen(_theGroupDidChange);

    modalView = modal_view_hidden;
    groupCardView = group_card_view_hidden;
  }

  // Action handlers

  Future _signIn(_) async => _client.signIn();

  Future _signOut(_) async => _client.signOut();

  Future _joinGroup(String uid) async => _client.joinGroup(uid);

  Future _leaveGroup(_) async => _client.leaveGroup();

  Future _createGroup(String name) async {
    expectedGroup = await _client.createGroup(name);
  }

  Future _deleteGroup(String uid) async => _client.deleteGroup(uid);

  Future _updateDescription(String text) async => _client.updateDescription(text);

  Future _disableOption(String uid) async => _client.disableOption(uid);

  Future _enableOption(String uid) async => _client.enableOption(uid);

  Future _disableUser(String uid) async => _client.disableUser(uid);

  Future _enableUser(String uid) async => _client.enableUser(uid);

  Future _createOption(String name) async {
    expectedOption = await _client.createOption(name);
  }

  Future _deleteOption(String uid) async => _client.deleteOption(uid);

  /// Pick randomly from the list of enabled options.
  Future _createPick(_) async {
    if (theGroup == null) return;
    List<String> optionUids = new List<String>.from(theGroup.options.where((optionUid) {
      if (optionIsDeleted(optionUid)) return false;
      if (optionIsBlocked(optionUid)) return false;
      if (optionCreatorIsBlocked(optionUid)) return false;
      return true;
    }));
    if (optionUids.length == 0) return;
    expectedPick = await _client.createPick(optionUids[new Random().nextInt(optionUids.length)]);
  }

   _groupDidChange(String uid) {
    groups.clear();
    groups.addAll(_client.groups);
    if (uid == expectedGroup) {
      expectedGroup = null;
      _client.joinGroup(uid);
    }
   }
   
  _optionDidChange(String uid) {
    options.clear();
    options.addAll(_client.options);
    if (uid == expectedOption) {
      expectedOption = null;
      if (modalView == modal_view_create_option) modalView == modal_view_hidden;
    }
  }

  _pickDidChange(String uid) {
    picks.clear();
    picks.addAll(_client.picks);
    if (uid == expectedPick) {
      theOption = option(pick(uid).option);
      expectedPick = null;
      if (modalView == modal_view_hidden) modalView = modal_view_show_pick;
    }
  }

  _userDidChange(String uid) {
    users.clear();
    users.addAll(_client.users);
  }

  _theUserDidChange(UserData data) {
    theUser = data;
  }

  _theGroupDidChange(GroupData data) {
    theGroup = data;
    if (data != null && groupCardView == group_card_view_hidden) {
      groupCardView = group_card_view_options;
    } else if (data == null && groupCardView != group_card_view_hidden) {
      groupCardView = group_card_view_hidden;
    }
  }

  String fmtDate(String date) => date != null ? new DateFormat.yMEd().add_jms().format(DateTime.parse(date)) : '';

  String fmtAgo(String date) {
    if (date == null) return 'forever ago';
    Duration period = new DateTime.now().difference(DateTime.parse(date));
    int days = period.inDays;
    if (days == 0) {
      int hours = period.inHours;
      if (hours == 0) {
        int minutes = period.inMinutes;
        if (minutes == 0) return "just now";
        if (minutes == 1) return "1 minute ago";
        return "${minutes} minutes ago";
      }
      if (hours == 1) return "1 hour ago";
      return "${hours} hours ago";
    }
    if (days == 1) return "1 day ago";
    return "${days} days ago";
  }
}
