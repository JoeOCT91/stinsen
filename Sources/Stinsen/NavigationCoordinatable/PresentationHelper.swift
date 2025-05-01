import Foundation
import Combine
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    let navigationStack: NavigationStack<T>
    private var cancellables = Set<AnyCancellable>()
    
    @Published var presented: Presented?
    
    func setupPresented(coordinator: T) {
        let value = self.navigationStack.value
        
        let nextId = id + 1
        
        // Only apply updates on last screen in navigation stack
        // This check is important to get the behaviour as using a bool-state in the view that you set
        if value.count - 1 == nextId, self.presented == nil {
            if let value = value[safe: nextId] {
                let presentable = value.presentable
                switch value.presentationType {
                case .modal:
                    if presentable is AnyView {
                        // Create a NavigationCoordinatableView for the next screen in the stack
                        let view = NavigationCoordinatableView(id: nextId, coordinator: coordinator)
                        // The router is automatically added to the environment in NavigationCoordinatableView
                        
                        self.presented = Presented(
                            view: AnyView(
                                SwiftUI.NavigationStack {
                                    AnyView(view)
                                }
                            ),
                            type: .modal
                        )
                    } else {
                        self.presented = Presented(
                            view: presentable.view(),
                            type: .modal
                        )
                    }
                case .push:
                    // For push navigation, we'll use the NavigationPath in the stack
                    // No need to create a presented view since it will be handled by the NavigationStack
                    if presentable is AnyView {
                        // We don't need to set presented for push navigation anymore
                        // This will be handled by the coordinatorStack.navigationPath
                        navigationStack.updateNavigationPath()
                    } else {
                        // For non-AnyView presentables, fall back to the old behavior
                        self.presented = Presented(
                            view: presentable.view(),
                            type: .push
                        )
                    }
                case.fullScreen:
                    if presentable is AnyView {
                        // Create a NavigationCoordinatableView for the next screen in the stack
                        let view = NavigationCoordinatableView(id: nextId, coordinator: coordinator)
                        // The router is automatically added to the environment in NavigationCoordinatableView
                        
                        self.presented = Presented(
                            view: AnyView(
                                SwiftUI.NavigationStack {
                                    AnyView(view)
                                }
                            ),
                            type: .fullScreen
                        )
                    } else {
                        self.presented = Presented(
                            view: AnyView(
                                presentable.view()
                            ),
                            type: .fullScreen
                        )
                    }
                }
            }
        }
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.navigationStack = coordinator.stack
        
        self.setupPresented(coordinator: coordinator)
        
        navigationStack.$value.dropFirst().sink { [weak self, coordinator] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.setupPresented(coordinator: coordinator)
            }
        }
        .store(in: &cancellables)
        
        navigationStack.poppedTo.filter { int -> Bool in int <= id }.sink { [weak self] int in
            // remove any and all presented views if my id is less than or equal to the view being popped to!
            DispatchQueue.main.async { [weak self] in
                self?.presented = nil
            }
        }
        .store(in: &cancellables)
    }
}
