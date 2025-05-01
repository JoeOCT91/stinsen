import Foundation
import Combine
import SwiftUI

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    let child: ViewPresentable
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
public class NavigationRoot: ObservableObject {
    @Published var item: NavigationRootItem
    
    init(item: NavigationRootItem) {
        self.item = item
    }
}

/// Represents a coordinator's navigation stack and integrates with SwiftUI.NavigationStack.
/// This class manages both traditional Stinsen navigation and SwiftUI's NavigationPath-based navigation.
public class CoordinatorNavigationStack<T: NavigationCoordinatable>: ObservableObject {
    var dismissalAction: [Int: () -> Void] = [:]
    
    weak var parent: ChildDismissable?
    var poppedTo = PassthroughSubject<Int, Never>()
    let initial: PartialKeyPath<T>
    let initialInput: Any?
    var root: NavigationRoot!
    
    /// The stack of navigation items (screens/coordinators)
    @Published var value: [NavigationStackItem]
    
    /// The SwiftUI navigation path for use with SwiftUI.NavigationStack
    @Published var navigationPath = NavigationPath()
    
    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self.value = []
        self.initial = initial
        self.initialInput = initialInput
        self.root = nil
    }
    
    /// Updates the SwiftUI navigation path when stack changes
    /// This synchronizes the traditional Stinsen navigation stack with
    /// SwiftUI's NavigationPath for SwiftUI.NavigationStack compatibility
    func updateNavigationPath() {
        // We only include push navigation items in the path
        let pathItems = value.filter { $0.presentationType.isPush }
        
        // Clear the path and rebuild it
        navigationPath = NavigationPath()
        
        // Add each item to the path
        for item in pathItems {
            // Using the keyPath as an identifier
            navigationPath.append(item.keyPath)
        }
    }
}

/// Convenience checks against the navigation stack's contents
public extension CoordinatorNavigationStack {
    /**
        The Hash of the route at the top of the stack
        - Returns: the hash of the route at the top of the stack or -1
     */
    var currentRoute: Int {
        return value.last?.keyPath ?? -1
    }

    /**
    Checks if a particular KeyPath is in a stack
     - Parameter keyPathHash:The hash of the keyPath
     - Returns: Boolean indiacting whether the route is in the stack
     */
    func isInStack(_ keyPathHash: Int) -> Bool {
        return value.contains { $0.keyPath == keyPathHash }
    }

    /**
    Checks if a parent coordinator
     - Returns: Boolean indiacting whether the coordinator has a parent
     */
    func hasParent() -> Bool {
        return self.parent != nil
    }
}

/// Represents an item in the navigation stack
struct NavigationStackItem: Identifiable, Hashable {
    let presentationType: PresentationType
    let presentable: ViewPresentable
    let keyPath: Int
    let input: Any?
    
    // Required for Identifiable protocol
    var id: Int { keyPath }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
    }
    
    static func == (lhs: NavigationStackItem, rhs: NavigationStackItem) -> Bool {
        return lhs.keyPath == rhs.keyPath
    }
}

// For backward compatibility
public typealias NavigationStack<T: NavigationCoordinatable> = CoordinatorNavigationStack<T>
