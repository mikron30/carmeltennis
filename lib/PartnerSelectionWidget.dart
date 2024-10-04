class PartnerSelection extends StatefulWidget {
  final Function(String) onPartnerSelected;
  final List<String>
      suggestionsList; // Suggestions list to populate autocomplete
  final List<String>
      lastSelectedPartners; // Last selected partners for dropdown

  PartnerSelection({
    required this.onPartnerSelected,
    required this.suggestionsList,
    required this.lastSelectedPartners,
  });

  @override
  _PartnerSelectionState createState() => _PartnerSelectionState();
}

class _PartnerSelectionState extends State<PartnerSelection> {
  TextEditingController _partnerController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // Autocomplete text box
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return widget.suggestionsList.where((String option) {
              return option
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            widget.onPartnerSelected(selection);
            _partnerController.text = selection; // Update the text box
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode,
              VoidCallback onFieldSubmitted) {
            _partnerController =
                fieldTextEditingController; // Assign controller
            return TextField(
              controller: _partnerController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                hintText: "הכנס שם שותף",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    // Show a dropdown menu with last 5 partners
                    showMenu<String>(
                      context: context,
                      position: RelativeRect.fromLTRB(0, 40, 0, 0),
                      items: widget.lastSelectedPartners.map((String partner) {
                        return PopupMenuItem<String>(
                          value: partner,
                          child: Text(partner),
                        );
                      }).toList(),
                    ).then((String? newValue) {
                      if (newValue != null) {
                        widget.onPartnerSelected(newValue);
                        _partnerController.text = newValue;
                      }
                    });
                  },
                ),
              ),
            );
          },
          optionsViewBuilder: (BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                child: Container(
                  width: 300,
                  height: 200,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10.0),
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return GestureDetector(
                        onTap: () {
                          onSelected(option);
                        },
                        child: ListTile(
                          title: Text(option),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
