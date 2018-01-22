class DictionaryEntry {
    string key;
    dictionaryValue value;    
}

class Dictionary {
    DictionaryEntry@[] entries;

    /*dictionaryValue get_opIndex(string index) {
        return dictionaryValue();
    }

    void set_opIndex(string& index, dictionaryValue value) {

    }*/

    bool exists(string key) {
        return false;
    }

    array<string> getKeys() {
        string[] r;
        return r;
    }

}