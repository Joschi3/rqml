import QtQuick
import QtTest
import RQml.Elements

Item {
    height: 120
    width: 400

    SearchBar {
        id: searchBar

        property int nextRequestedCount: 0

        anchors.centerIn: parent
        debounceInterval: 500
        width: 280

        onNextRequested: nextRequestedCount += 1
    }
    TestCase {
        function findChildByObjectName(parent, objectName) {
            if (!parent)
                return null;
            if (parent.objectName === objectName)
                return parent;
            var children = parent.children || [];
            for (var i = 0; i < children.length; ++i) {
                var found = findChildByObjectName(children[i], objectName);
                if (found)
                    return found;
            }
            return null;
        }
        function init() {
            searchBar.clear();
            searchBar.nextRequestedCount = 0;
            wait(10);
        }
        function test_return_commits_pending_search_text() {
            var field = findChildByObjectName(searchBar, "searchBarTextField");
            verify(field !== null, "Search text field should exist");
            mouseClick(field);
            for (var i = 0; i < 6; ++i)
                keyClick("Sensor"[i]);
            compare(searchBar.text, "", "Debounce should keep exposed text empty before Enter");
            keyClick(Qt.Key_Return);
            compare(searchBar.text, "sensor", "Enter should flush the pending query immediately");
            compare(searchBar.nextRequestedCount, 1, "Enter should still trigger next navigation");
        }

        name: "SearchBarTest"
        when: windowShown
    }
}
