import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem
import Ubuntu.Components.Popups 1.3
// import Ubuntu.Contacts 0.1
import "../components"
import "../components/listitems"
import "../js/avatar.js" as Avatar
import "../js/time.js" as Time

TelegramPage {
    id: contactsPage

    // These values are passed on page creation.
    property bool groupChatMode: false
    property bool addToGroupMode: false
    property alias groupTitle: groupChatTitleTextField.text
    property bool blockUserMode: false
    property int groupChatId: -1
    property string groupChatTitle: ""

    property alias isSelectingGroup: contactListView.isInSelectionMode
    property bool isGroupCountSatisfied: addToGroupMode || contactListView.selectedItems.count > 0
    property var actionsNone: []
    property list<Action> actionIsSearching: [
            Action {
                     iconName: "close"
                     text: i18n.tr("Close")
                     visible: isSearching
                     onTriggered: isSearching = false;
                 }]
    property list<Action> actionsSearch: [
        Action {
            iconName: "search"
            text: i18n.tr("Search")
            onTriggered: searchPressed()
        }
    ]
    property list<Action> actionsNewChat: [
        Action {
            iconName: "search"
            text: i18n.tr("Search")
            onTriggered: searchPressed()
        },
        Action {
            iconName: "reload"
            text: i18n.tr("Refresh")
            onTriggered: refreshContacts()
        },
        Action {
            iconName: "add"
            text: i18n.tr("Add contact")
            onTriggered: {
                PopupUtils.open(Qt.resolvedUrl("dialogs/AddContactDialog.qml"),
                contactsPage, {
                    title: i18n.tr("Add Contact"),
                    // onAccept: function() {
                    //   console.log(inputName)
                    //   console.log(inputName.text)
                    //   getPhoneNumber()
                    //   // addContact()
                    // }
                })
            }
        }
    ]
    property list<Action> actionsNewGroupChat: [
        Action {
            iconName: "ok"
            text: i18n.tr("OK")
            enabled: isConnected && groupChatTitleTextField.length > 0
            onTriggered: createChatPressed()
        }
    ]
    header:PageHeader{
      title: {
          if (groupChatMode) {
              return i18n.tr("New group");
          } else if (addToGroupMode) {
              return i18n.tr("Update group");
          } else {
              return i18n.tr("Contacts");
          }
      }
      leadingActionBar.actions:[
        Action {
          id: backAction
          iconName: "back"
          onTriggered:{
              backToChatListPage();
          }
        }
      ]
      trailingActionBar.actions: {
          if (isSearching) {
              return actionIsSearching;
          } else if (isSelectingGroup) {
              return isGroupCountSatisfied ? actionsNewGroupChat : actionsSearch;
          } else {
              // also includes blockUserMode
              return actionsNewChat;
          }
      }
      TextField {
          id: searchField
          visible: isSearching
          enabled: isSearching
          anchors {
              left: parent.left
              rightMargin: units.gu(2)
              leftMargin: units.gu(2)
              topMargin: units.gu(1)
              top: parent.top
          }
          inputMethodHints: Qt.ImhNoPredictiveText

          onTextChanged: {
              if (typeof onSearchTermChanged === 'function') {
                  onSearchTermChanged(text);
              }
          }
      }
    }

    pageSubtitle: ""

    body: Item {
        anchors.fill: parent

        Label {
            id: listEmptyLabel
            anchors.centerIn: parent
            fontSize: "medium"
            visible: contactListView.model.count === 0
            text: i18n.tr("No contacts")
        }

        TextField {
            // Use height and opacity, we can't animate on visibility.
            property bool isVisible: isGroupCountSatisfied

            id: groupChatTitleTextField
            anchors {
                top: parent.top
                topMargin: isVisible ? units.gu(1) : 0
                left: parent.left
                leftMargin: units.gu(1)
                right: parent.right
                rightMargin: units.gu(1)
            }
            height: isVisible ? units.gu(4) : 0
            opacity: isVisible ? 1.0 : 0.0
            placeholderText: i18n.tr("Group name")
            Keys.onReturnPressed: {
                Qt.inputMethod.commit();
                contactListView.updateOrCreateGroup();
            }


            Behavior on height {
                NumberAnimation { duration: 300 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }

        MultipleSelectionListView {
            id: contactListView
            property string sels : ""
            property var sela: []
            anchors {
                top: groupChatTitleTextField.visible ? groupChatTitleTextField.bottom : parent.top
                topMargin: groupChatTitleTextField.isVisible ? units.gu(1) : 0
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            clip: true

            section {
                property: "firstName"
                criteria: ViewSection.FirstCharacter
                labelPositioning: ViewSection.InlineLabels
                delegate: ListItem.Header {
                    text: section != "" ? section : "#"
                }
            }

            listModel: contactsModel.len
            listDelegate: ContactsListItem {
                id: contactDelegate
                property var contact : contactsModel.getContact(index)
                userId: uid(contact.tel)
                photo: avatarImage(contact.tel)
                title: contact.name
                subtitle: contact.tel

                selected: contactListView.isSelected(contactDelegate)
                selectionMode: groupChatMode || addToGroupMode

                onItemClicked: {
                    if (contactListView.isInSelectionMode) {
                        contactListView.selectionToggled(contact.tel);
                        if (!contactListView.selectItem(contactDelegate)) {
                            contactListView.deselectItem(contactDelegate);
                        }
                        contactListView.refreshSubtitle();
                    } else {
                        // openSimpleChat(contact);
                    }
                }
            }

            onSelectedItemsChanged: {
                refreshSubtitle();
            }

            onSelectionCanceled: {
                groupChatMode = false;
            }

            onSelectionDone: {
                updateOrCreateGroup()
            }

            function updateOrCreateGroup() {
                if (contactsPage.addToGroupMode) {
                    contactListView.updateGroup();
                } else {
                    contactListView.createGroup();
                }
            }

            function updateGroup() {
                textsecure.updateGroup(messagesModel.tel, groupChatTitleTextField.text, sels)
                searchFinished();
                pageStack.pop();
            }

            function createGroup() {
                createChat(sels);

                groupChatMode = false;
                groupChatTitleTextField.text = "";
            }
            function selectionToggled(contact) {
                var a = contactListView.sela
                var i = a.indexOf(contact)
                if (i == -1) {
                    a.push(contact)
                } else {
                    a.splice(i, 1)
                }

                contactListView.sels = a.join(",")
            }

            function refreshSubtitle() {
                var count = contactListView.selectedItems.count;
                if (groupChatMode && count > 0) {
                    pageSubtitle = i18n.tr("%1 members").arg(count);
                } else {
                    pageSubtitle = "";
                }
            }
        }

        Scrollbar {
            flickableItem: contactListView
        }

        Component.onCompleted: {
            if (!textsecure.hasContacts) {
                //FIXME hasContacts returns always false
                // refreshContacts();
            }
        }

    }

    function modeChanged() {
        if (groupChatMode || addToGroupMode) {
            contactListView.startSelection();
        } else {
            contactListView.cancelSelection();
        }
        contactListView.refreshSubtitle();
    }

    onGroupChatModeChanged: modeChanged()
    onAddToGroupModeChanged: modeChanged()

    function createChatPressed() {
        Qt.inputMethod.commit();

        var isSimpleChat = contactListView.isInSelectionMode ?
                    contactListView.selectedItems.count == 1 : true;

        var isGroupChat = !isSimpleChat
        var hasGroupTitle = groupChatTitleTextField.text.length > 0;

        if (isSimpleChat || (isGroupChat && hasGroupTitle)) {
            contactListView.endSelection();
        }
    }

    function onBackPressed() {
        contactListView.cancelSelection();
    }
    function addContact(name, phone) {
      textsecure.addContact(name, phone)
    }
    function getPhoneNumber() {
      console.log(inputName.text)
      // var n = "+" + countryTextField.text + userTextField.text;
      // return n.replace(/[\s\-\(\)]/g, '')
    }
    function cancelChatPressed() {
        contactListView.cancelSelection();
    }

    function createChat(items) {
        if (items.count === 1) {
            var contact = items.get(0).model;
            openSimpleChat(contact);
        } else {
            openGroupChat(items);
        }
    }

    function openSimpleChat(contact) {
        console.log("openSimpleChat")
        Qt.inputMethod.hide();
        searchFinished();
        openChatById(contact.name, contact.tel);
    }

    function openGroupChat(contacts) {
        textsecure.newGroup(groupChatTitleTextField.text, contacts)
        searchFinished();
        pageStack.pop();
    }

    function onSearchTermChanged(t) {
        textsecure.filterContacts(t)
    }

    ContactImport {
        id: contactImporter
    }

    function refreshContacts() {
        contactImporter.contactImportDialog()
    }
}
