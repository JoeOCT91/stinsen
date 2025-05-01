import Foundation
import SwiftUI
import Combine

struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    private let router: NavigationRouter<T>
    @ObservedObject var presentationHelper: PresentationHelper<T>
    @ObservedObject var root: NavigationRoot
    @ObservedObject private var coordinatorStack: NavigationStack<T>
    
    var start: AnyView?

    var body: some View {
        if id == -1 {
            // This is the root level view
            SwiftUI.NavigationStack(path: Binding<NavigationPath>(
                get: { self.coordinatorStack.navigationPath },
                set: { newPath in
                    if newPath.count < self.coordinatorStack.navigationPath.count {
                        // Handle back navigation
                        let popToIndex = newPath.count
                        if popToIndex >= 0 {
                            if let pathElement = self.coordinatorStack.value.filter({ $0.presentationType.isPush })[safe: popToIndex] {
                                self.coordinatorStack.poppedTo.send(pathElement.keyPath)
                            }
                        }
                    }
                    self.coordinatorStack.navigationPath = newPath
                }
            )) {
                // Root content - Ensuring the router is injected here
                self.coordinator.customize(AnyView(root.item.child.view()))
                    .environmentObject(router)
                    .navigationDestination(for: Int.self) { keyPathHash in
                        createDestinationView(for: keyPathHash)
                            .environmentObject(router) // Make sure router is passed to destinations
                    }
            }
            .environmentObject(router) // Also inject at the NavigationStack level
            .background(
                createFullScreenCoverView()
            )
        } else {
            // This is a child view that will be embedded in the navigation stack
            contentView
                .environmentObject(router)
                .background(
                    createFullScreenCoverView()
                )
        }
    }
    
    private func createDestinationView(for keyPathHash: Int) -> some View {
        if let stackItem = self.coordinatorStack.value.first(where: { $0.keyPath == keyPathHash }) {
            if let view = stackItem.presentable as? AnyView {
                return view
                    .environmentObject(router) // Ensure router is passed here
                    .onDisappear(perform: handleDismissal)
            }
        }
        return AnyView(EmptyView())
    }
    
    // Regular view for non-root views
    @ViewBuilder
    var contentView: some View {
        if let startView = self.start {
            startView
                .environmentObject(router) // Ensure router is passed here
                .sheet(
                    isPresented: createModalPresentationBinding(),
                    onDismiss: handleDismissal,
                    content: createModalContent
                )
        } else {
            EmptyView()
        }
    }
    
    // Creates fullScreenCover view for fullScreen presentations
    private func createFullScreenCoverView() -> some View {
        Color.clear
            .fullScreenCover(
                isPresented: createFullScreenPresentationBinding(),
                onDismiss: handleDismissal,
                content: createFullScreenContent
            )
            .environmentObject(router)
    }
    
    // Creates binding for fullScreen presentation state
    private func createFullScreenPresentationBinding() -> Binding<Bool> {
        Binding<Bool>(
            get: { 
                return presentationHelper.presented?.type.isFullScreen == true
            },
            set: { _ in
                self.coordinator.appear(self.id)
            }
        )
    }
    
    // Creates the content for fullScreen presentation
    private func createFullScreenContent() -> AnyView {
        if let view = presentationHelper.presented?.view {
            return AnyView(view.environmentObject(router)) // Ensure router is passed here
        } else {
            return AnyView(EmptyView())
        }
    }
    
    // Creates binding for modal presentation state
    private func createModalPresentationBinding() -> Binding<Bool> {
        Binding<Bool>(
            get: { 
                return presentationHelper.presented?.type.isModal == true
            },
            set: { _ in
                self.coordinator.appear(self.id)
            }
        )
    }
    
    // Handles dismissal actions
    private func handleDismissal() {
        self.coordinator.stack.dismissalAction[id]?()
        self.coordinator.stack.dismissalAction[id] = nil
    }
    
    // Creates the content for modal presentation
    private func createModalContent() -> AnyView {
        if let view = presentationHelper.presented?.view {
            return AnyView(view.environmentObject(router)) // Ensure router is passed here
        } else {
            return AnyView(EmptyView())
        }
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        self.coordinatorStack = coordinator.stack
        
        self.presentationHelper = PresentationHelper(
            id: self.id,
            coordinator: coordinator
        )
        
        self.router = NavigationRouter(
            id: id,
            coordinator: coordinator.routerStorable
        )
        
        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }
        
        self.root = coordinator.stack.root

        RouterStore.shared.store(router: router)
        
        if let presentation = coordinator.stack.value[safe: id] {
            if let view = presentation.presentable as? AnyView {
                self.start = view
            } else {
                fatalError("Can only show views")
            }
        } else if id == -1 {
            self.start = nil
        } else {
            fatalError()
        }
    }
}
