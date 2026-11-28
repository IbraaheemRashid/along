import SwiftUI
import UIKit

/// UIKit-backed field for email/password entry. Avoids SwiftUI `TextField` crashes
/// when a sheet or `safeAreaInset` footer resizes under the software keyboard.
struct AlongTextField: UIViewRepresentable {
    enum Kind { case email, password, plain }

    @Binding var text: String
    var kind: Kind = .plain
    var placeholder = ""
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.borderStyle = .none
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        field.clearButtonMode = .whileEditing
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyKind(field)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        applyKind(field)
    }

    private func applyKind(_ field: UITextField) {
        switch kind {
        case .email:
            field.keyboardType = .emailAddress
            field.textContentType = .none
            field.autocapitalizationType = .none
            field.isSecureTextEntry = false
            field.returnKeyType = .done
        case .password:
            field.keyboardType = .default
            field.textContentType = .none
            field.autocapitalizationType = .none
            field.isSecureTextEntry = true
            field.returnKeyType = .go
        case .plain:
            field.keyboardType = .default
            field.textContentType = .none
            field.autocapitalizationType = .sentences
            field.isSecureTextEntry = false
            field.returnKeyType = .done
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AlongTextField
        init(_ parent: AlongTextField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onSubmit?()
            return false
        }
    }
}

struct AlongFormField: View {
    @Binding var text: String
    var kind: AlongTextField.Kind
    var placeholder: String
    var identifier: String
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        AlongTextField(text: $text, kind: kind, placeholder: placeholder, onSubmit: onSubmit)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(14)
            .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier(identifier)
    }
}
