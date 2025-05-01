import Foundation
import SwiftUI
import Combine

struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    private let router: NavigationRouter<T>
    @ObservedObject var presentationHelper: PresentationHelper<T>
    @ObservedObject var root: NavigationRoot
    
    var start: AnyView?

    var body: some View {
        commonView
            .environmentObject(router)
            .background(
                createFullScreenCoverView()
            )
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
            return AnyView(view)
        } else {
            return AnyView(EmptyView())
        }
    }
    
    @ViewBuilder
    var commonView: some View {
        let mainContent = id == -1 
            ? AnyView(self.coordinator.customize(AnyView(root.item.child.view()))) 
            : AnyView(self.start!)
        
        mainContent
            .background(
                createHiddenNavigationLink()
            )
            .sheet(
                isPresented: createModalPresentationBinding(),
                onDismiss: handleDismissal,
                content: createModalContent
            )
    }
    
    // Creates the hidden navigation link for push navigation
    private func createHiddenNavigationLink() -> some View {
        NavigationLink(
            destination: createPushDestination(),
            isActive: createPushNavigationBinding(),
            label: { EmptyView() }
        )
        .hidden()
    }
    
    // Creates the destination view for push navigation
    private func createPushDestination() -> AnyView {
        if let view = presentationHelper.presented?.view {
            return AnyView(view.onDisappear(perform: handleDismissal))
        } else {
            return AnyView(EmptyView())
        }
    }
    
    // Creates binding for push navigation state
    private func createPushNavigationBinding() -> Binding<Bool> {
        Binding<Bool>(
            get: { 
                return presentationHelper.presented?.type.isPush == true
            },
            set: { _ in
                self.coordinator.appear(self.id)
            }
        )
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
            return AnyView(view)
        } else {
            return AnyView(EmptyView())
        }
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        
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
