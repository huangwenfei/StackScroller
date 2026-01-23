//
//  StackScrollView.swift
//  Xiaosuimian
//
//  Created by windy on 2025/2/20.
//

import UIKit

// MARK: StackScrollContent
 
public protocol StackScrollContent: UIView {
    associatedtype Model: Hashable
    var model: Model? { get set }
    var isDisplayed: Bool { get set }
    var page: Int { get set }
    func renderPlaceholder()
    func render(model: Model)
    func prepareForReuse()
}

extension StackScrollContent {
    
    internal func renderIfNeed(model: Model) {
        guard isDisplayed == false else { return }
        render(model: model)
        isDisplayed = true
    }
    
    internal func resetForReuse() {
        model = nil
        isDisplayed = false
        tag = -1
        page = -1
        frame = .zero
        scaleStepInitFrame = .zero
        transform = .identity
        scaleStep = 1.0
        scaleStepAnimated = 1.0
        scaleStepZIndex = 0
        prepareForReuse()
    }
    
}

private struct StackScrollContentScaleStepKeys {
    static var scaleStep: UInt8 = 0
    static var scaleStepAnimated: UInt8 = 1
    static var zIndex: UInt8 = 2
    static var initFrame: UInt8 = 3
}

extension StackScrollContent {
    
    internal var scaleStep: CGFloat {
        get {
            guard
                let value = objc_getAssociatedObject(
                    self, &StackScrollContentScaleStepKeys.scaleStep
                ) as? NSNumber
            else {
                return 1.0
            }
            
            return CGFloat(value.floatValue)
        }
        set {
            objc_setAssociatedObject(
                self,
                &StackScrollContentScaleStepKeys.scaleStep,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    internal var scaleStepAnimated: CGFloat {
        get {
            guard
                let value = objc_getAssociatedObject(
                    self, &StackScrollContentScaleStepKeys.scaleStepAnimated
                ) as? NSNumber
            else {
                return 1.0
            }
            
            return CGFloat(value.floatValue)
        }
        set {
            objc_setAssociatedObject(
                self,
                &StackScrollContentScaleStepKeys.scaleStepAnimated,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    internal var scaleStepZIndex: Int {
        get {
            guard
                let value = objc_getAssociatedObject(
                    self, &StackScrollContentScaleStepKeys.zIndex
                ) as? NSNumber
            else {
                return 0
            }
            
            return value.intValue
        }
        set {
            objc_setAssociatedObject(
                self,
                &StackScrollContentScaleStepKeys.zIndex,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    internal var scaleStepInitFrame: CGRect {
        get {
            guard
                let value = objc_getAssociatedObject(
                    self, &StackScrollContentScaleStepKeys.initFrame
                ) as? NSValue
            else {
                return .zero
            }
            
            return value.cgRectValue
        }
        set {
            objc_setAssociatedObject(
                self,
                &StackScrollContentScaleStepKeys.initFrame,
                NSValue(cgRect: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

// MARK: - StackScrollViewDelegate

public protocol StackScrollViewDelegate: NSObjectProtocol {
    associatedtype Item: StackScrollContent
    
    func item(at page: Int) throws -> Item
    
}

// MARK: - StackScrollViewInsets

public struct StackScrollViewInsets: Hashable, Codable {
    
    public var horizontal: CGFloat
    public var vertical: CGFloat
    
    public static let zero: Self = .init()
    
    public init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
    
    public init(value same: CGFloat = 0) {
        self.horizontal = same
        self.vertical = same
    }
    
}

// MARK: - StackSctollViewSize

public enum StackSctollViewSize: Hashable {
    
    case unspecified,
         rect(_ same: CGFloat),
         custom(size: CGSize)
    
    public func size(in bounds: CGSize) -> CGSize {
        
        let maxWidth = bounds.width
        let maxHeight = bounds.height
        
        switch self {
        case .unspecified:
            return bounds
            
        case .rect(let same):
            return .init(
                width: min(same, maxWidth, maxHeight),
                height: min(same, maxWidth, maxHeight)
            )
            
        case .custom(let size):
            return .init(
                width: min(size.width, maxWidth),
                height: min(size.height, maxHeight)
            )
        }
    }
    
    // MARK: Hashable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .unspecified:
            switch rhs {
            case .unspecified:   return true
            case .rect, .custom: return false
            }
            
        case .rect(let lValue):
            switch rhs {
            case .rect(let rValue):     return lValue == rValue
            case .unspecified, .custom: return false
            }
            
        case .custom(let lValue):
            switch rhs {
            case .custom(let rValue): return lValue == rValue
            case .unspecified, .rect: return false
            }
        }
    }
    
    public var value: String {
        switch self {
        case .unspecified:       return "unspecified"
        case .rect(let value):   return "rect \(value)"
        case .custom(let value): return "custom \(value)"
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    
}

// MARK: - StackScrollViewStackScaleBaseline

public enum StackScrollViewStackScaleBaseline: Int {
    case top, center, bottom
}

// MARK: - StackScrollViewMode

public enum StackScrollViewMode: Hashable {
    case normal(configs: StackNormalViewConfiguration)
    case normalCenterScale(configs: StackNormalCenterScaleViewConfiguration)
    case centerScale(configs: StackCenterScaleViewConfiguration)
    
    public var intMode: StackScrollViewIntMode {
        switch self {
        case .normal:            return .normal
        case .normalCenterScale: return .normalCenterScale
        case .centerScale:       return .centerScale
        }
    }
    
    public var configs: StackScrollViewConfigProtocol {
        switch self {
        case .normal(let configs):            return configs
        case .normalCenterScale(let configs): return configs
        case .centerScale(let configs):       return configs
        }
    }
    
    public var isNormal: Bool {
        switch self {
        case .normal: return true
        default:      return false
        }
    }
    
    public var isNormalScale: Bool {
        switch self {
        case .normalCenterScale: return true
        default:                 return false
        }
    }
    
    public var isCenterScale: Bool {
        switch self {
        case .centerScale: return true
        default:           return false
        }
    }
    
}

public enum StackScrollViewIntMode: Int, Hashable {
    case normal, normalCenterScale, centerScale
}

// MARK: - StackScrollView

import UIKit
import Yang

public protocol StackScrollViewProtocol: UIView, StackScrollViewFuncProtocol {
    associatedtype Content: StackScrollContent
    
    var oldCurrentPage: Int { get set }
    var currentPage: Int { get set }
    var count: Int { get set }
    
    var isAsyncSource: Bool { get }
    var sourceProviderLegacy: ((_ page: Int) -> Content.Model)? { get }
    @available(iOS 13.0, *)
    var sourceProviderAsync: ((_ page: Int) async -> Content.Model)? { get }
    
    var pageChange: PageChangeClosure { get set }
    
    var visiableItems: [Content] { get } // 无序
    var reuseableItems: [Content] { get } // 无序
    
    func update(source: ((_ page: Int) -> Content.Model)?)
    @available(iOS 13.0, *)
    func update(source: ((_ page: Int) async -> Content.Model)?)
    
}

extension StackScrollViewProtocol {
    public typealias SourceProviderLegacy = (_ page: Int) -> Content.Model
    public typealias SourceProviderAsync = (_ page: Int) async -> Content.Model
    
    public typealias PageChangeClosure = (_ old: Int, _ new: Int) -> Void
}

extension StackScrollViewProtocol {
    
    func renderIfNeed(page: Int, item: Content, completion: @escaping () -> Void) {
        
        func gcdRender() {
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                guard let model = sourceProviderLegacy?(page) else { return }
                DispatchQueue.main.async {
                    item.model = model
                    item.renderIfNeed(model: model)
                    completion()
                }
            }
        }
        
        @available(iOS 13.0, *)
        func taskRender() {
            Task.detached { [weak self] in
                guard let self else { return }
                guard let model = await sourceProviderAsync?(page) else { return }
                await MainActor.run {
                    item.model = model
                    item.renderIfNeed(model: model)
                    completion()
                }
            }
        }
        
        if item.isDisplayed == false {
            item.renderPlaceholder()
        }
        
//        if isAsyncSource, #available(iOS 13.0, *) {
//            print(#function, #line, sourceProviderLegacy, sourceProviderAsync)
//        } else {
//            print(#function, #line, sourceProviderLegacy)
//        }
        
        if isAsyncSource, #available(iOS 13.0, *) {
            if sourceProviderAsync != nil {
                taskRender()
            } else {
                gcdRender()
            }
        } else {
            gcdRender()
        }
    }
    
}

extension StackScrollViewProtocol {
    public var firstPage: Int {
        0
    }
    
    public var lastPage: Int {
        max(count - 1, 0)
    }
    
    public var centerPage: Int {
        Int(ceil(.init(lastPage) * 0.5))
    }
    
    public func vaildPage(_ page: Int) -> Bool {
        (0 ..< count).contains(page)
    }
    
    public func clampPage(_ page: Int) -> Int {
        min(max(page, 0), max(count - 1, 0))
    }
}


public protocol StackScrollViewConfigProtocol: Hashable {
    
}


public protocol StackScrollViewFuncProtocol: UIView {
    
    func previewPage()
    func nextPage()
    /// If there are no items on the current page, we will automatically jump to the last item.
    func loopPreviewPage()
    /// When there are no more items, it will automatically jump to the first item.
    func loopNextPage()
    
    func update(currentPage: Int)
    
    /// Start scrolling is called
    var beginScroll: StackBeginScrollClosure? { get set }
    /// Called when scrolling changes
    var changeScroll: StackChangeScrollClosure? { get set }
    /// Is called to end scrolling
    var endScroll: StackEndScrollClosure? { get set }
    
}

extension StackScrollViewFuncProtocol {
    public typealias StackBeginScrollClosure = (_ stack: any StackScrollViewProtocol) -> Void
    public typealias StackChangeScrollClosure = (_ stack: any StackScrollViewProtocol, _ progress: CGFloat) -> Void
    public typealias StackEndScrollClosure = (_ stack: any StackScrollViewProtocol) -> Void
}

extension StackScrollViewFuncProtocol {
    var isVaildSize: Bool {
        bounds.width != .zero && bounds.height != .zero
    }
    
    public func setNeedsUpdate() {
        setNeedsUpdateConstraints()
        setNeedsLayout()
        setNeedsDisplay()
    }
}

extension StackScrollViewFuncProtocol {
    public func setBeginObserver(_ closure: StackBeginScrollClosure?) {
        self.beginScroll = closure
    }
    
    public func setChangeObserver(_ closure: StackChangeScrollClosure?) {
        self.changeScroll = closure
    }
    
    public func setEndObserver(_ closure: StackEndScrollClosure?) {
        self.endScroll = closure
    }
}


open class StackScrollView<Content>: UIView, StackScrollViewFuncProtocol
    where Content: StackScrollContent
{
    // MARK: Type
    public typealias Content = Content
    public typealias Model = Content.Model
    
    public typealias SourceProviderLegacy = (_ page: Int) -> Model
    public typealias SourceProviderAsync = (_ page: Int) async -> Model
    
    public typealias PageChangeClosure = StackScrollViewProtocol.PageChangeClosure
    
    // MARK: Properties
    open var mode: StackScrollViewMode
    open private(set) var container: (any StackScrollViewProtocol)!
    
    open private(set) var isAsyncSource: Bool
    open private(set) var sourceProviderLegacy: SourceProviderLegacy?
    
    @available(iOS 13.0, *)
    open private(set) var sourceProviderAsync: SourceProviderAsync? {
        get { _sourceProviderAsync }
        set { _sourceProviderAsync = newValue }
    }
    private var _sourceProviderAsync: SourceProviderAsync?
    
    // MARK: Properties - Container Page
    open var currentPage: Int {
        container.currentPage
    }
    
    open var count: Int {
        container.count
    }
    
    // MARK: Properties - Container Scroll
    open var beginScroll: StackBeginScrollClosure? {
        get { container.beginScroll }
        set { container.setBeginObserver(newValue) }
    }
    
    open var changeScroll: StackChangeScrollClosure? {
        get { container.changeScroll }
        set { container.setChangeObserver(newValue) }
    }
    
    open var endScroll: StackEndScrollClosure? {
        get { container.endScroll }
        set { container.setEndObserver(newValue) }
    }
    
    // MARK: Init
    public init(
        frame: CGRect = .zero,
        currentPage: Int = 0,
        count: Int,
        mode: StackScrollViewMode,
        sourceProvider: SourceProviderLegacy?,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        self.mode = mode
        self.isAsyncSource = false
        super.init(frame: frame)
        
        self.sourceProviderLegacy = sourceProvider
        self._sourceProviderAsync = nil
        
        createContainer(
            by: mode,
            currentPage: currentPage,
            count: count,
            sourceProvider: sourceProvider,
            pageChange: pageChange
        )
        container.yang.addToParent(self)
    }
    
    @available(iOS 13.0, *)
    public init(
        frame: CGRect = .zero,
        currentPage: Int = 0,
        count: Int,
        mode: StackScrollViewMode,
        sourceProvider: SourceProviderAsync?,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        self.mode = mode
        self.isAsyncSource = true
        super.init(frame: frame)
        
        self.sourceProviderLegacy = nil
        self._sourceProviderAsync = sourceProvider
        
        createContainer(
            by: mode,
            currentPage: currentPage,
            count: count,
            sourceProvider: sourceProvider,
            pageChange: pageChange
        )
        container.yang.addToParent(self)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createContainer(
        by mode: StackScrollViewMode,
        currentPage: Int = 0,
        count: Int,
        sourceProvider: SourceProviderLegacy?,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        switch mode {
        case .normal(let configs):
            container = StackNormalView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                sourceProvider: sourceProvider,
                pageChange: pageChange
            )
            
        case .normalCenterScale(let configs):
            container = StackNormalCenterScaleView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                sourceProvider: sourceProvider,
                pageChange: pageChange
            )
            
        case .centerScale(let configs):
            container = StackCenterScaleView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                sourceProvider: sourceProvider,
                pageChange: pageChange
            )
        }
    }
    
    @available(iOS 13.0, *)
    private func createContainer(
        by mode: StackScrollViewMode,
        currentPage: Int = 0,
        count: Int,
        sourceProvider: SourceProviderAsync?,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        switch mode {
        case .normal(let configs):
            container = StackNormalView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                sourceProvider: sourceProvider,
                pageChange: pageChange
            )
            
        case .normalCenterScale(let configs):
            container = StackNormalCenterScaleView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                sourceProvider: sourceProvider,
                pageChange: pageChange
            )
            
        case .centerScale(let configs):
            container = StackCenterScaleView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                sourceProvider: sourceProvider,
                pageChange: pageChange
            )
        }
    }
    
    deinit {
        beginScroll = nil
        changeScroll = nil
        endScroll = nil
    }
    
    // MARK: Layout
    open override func updateConstraints() {
        
        container.yangbatch.remake { make in
            make.diretionEdge.equalToParent()
        }
        
        super.updateConstraints()
    }
    
    // MARK: StackScrollViewFuncProtocol
    open func previewPage() {
        container.previewPage()
    }
    
    open func nextPage() {
        container.nextPage()
    }
    
    open func loopPreviewPage() {
        container.loopPreviewPage()
    }
    
    open func loopNextPage() {
        container.loopNextPage()
    }
    
    open func update(currentPage: Int) {
        container.update(currentPage: currentPage)
    }
    
    open func update(mode: StackScrollViewMode) {
        guard self.mode != mode else { return }
        
        container.yang.removeConstraints()
        container.yang.removeFromParent()
        
        if isAsyncSource, #available(iOS 13.0, *) {
            createContainer(
                by: mode,
                currentPage: container.currentPage,
                count: container.count,
                sourceProvider: sourceProviderAsync,
                pageChange: container.pageChange
            )
        } else {
            createContainer(
                by: mode,
                currentPage: container.currentPage,
                count: container.count,
                sourceProvider: sourceProviderLegacy,
                pageChange: container.pageChange
            )
        }
        self.mode = mode
        
        container.yang.addToParent(self)
        
        setNeedsUpdateConstraints()
        setNeedsLayout()
        setNeedsDisplay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.update(currentPage: self.container.currentPage)
        }
        
    }
    
    open func update(configs: StackScrollViewConfigProtocol) {
        
        let mode: StackScrollViewMode
        let old = self.mode.configs
        
        if
            let new = configs as? StackNormalViewConfiguration,
            self.mode.isNormal
        {
            if (old as! StackNormalViewConfiguration) == new {
                return
            }
            
            mode = .normal(configs: new)
        }
        else if
            let new = configs as? StackNormalCenterScaleViewConfiguration,
            self.mode.isNormalScale
        {
            if (old as! StackNormalCenterScaleViewConfiguration) == new {
                return
            }
            
            mode = .normalCenterScale(configs: new)
        }
        else if
            let new = configs as? StackCenterScaleViewConfiguration,
            self.mode.isCenterScale
        {
            if (old as! StackCenterScaleViewConfiguration) == new {
                return
            }
            
            mode = .centerScale(configs: new)
        }
        else {
            mode = self.mode
            debugPrint(#function, #line, "Unsupporting type: \(self.mode) \(configs) !")
        }
        
        update(mode: mode)
        
    }
    
    open func update(source: SourceProviderLegacy?) {
        isAsyncSource = false
        sourceProviderLegacy = source
        
        switch mode {
        case .normal(let configs):
            guard let container = container as? StackNormalView<Content> else {
                return
            }
            container.update(source: source)
            
        case .normalCenterScale(let configs):
            guard let container = container as? StackNormalCenterScaleView<Content> else {
                return
            }
            container.update(source: source)
            
        case .centerScale(let configs):
            guard let container = container as? StackCenterScaleView<Content> else {
                return
            }
            container.update(source: source)
        }
    }
    
    @available(iOS 13.0, *)
    open func update(source: SourceProviderAsync?) {
        isAsyncSource = true
        _sourceProviderAsync = source
        
        switch mode {
        case .normal(let configs):
            guard let container = container as? StackNormalView<Content> else {
                return
            }
            container.update(source: source)
            
        case .normalCenterScale(let configs):
            guard let container = container as? StackNormalCenterScaleView<Content> else {
                return
            }
            container.update(source: source)
            
        case .centerScale(let configs):
            guard let container = container as? StackCenterScaleView<Content> else {
                return
            }
            container.update(source: source)
        }
    }
    
}

// MARK: - StackColorItem

#if DEBUG
public final class StackColorItem: UIView, StackScrollContent {
    
    public typealias Model = Int
    
    public var model: Int? = nil
    
    public lazy var text: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 40)
        label.numberOfLines = 1
        label.backgroundColor = .clear
        label.layer.shadowColor = UIColor.black.withAlphaComponent(0.5).cgColor
        label.layer.shadowOffset = .init(width: 0, height: 1)
        label.layer.shadowOpacity = 1
        label.layer.shadowRadius = 4
        return label
    }()
    
    public var isDisplayed: Bool = false
    
    private static let colors: [UIColor] = [
        .yellow, .gray, .blue, .brown,
        .systemPink, .purple, .red, .green,
        .orange, .magenta, .cyan
    ]
    
    public var page: Int = -1
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(text)
        layer.shadowColor = UIColor.black.withAlphaComponent(0.2).cgColor
        layer.shadowOffset = .init(width: 0, height: 0)
        layer.shadowOpacity = 1
        layer.shadowRadius = 4
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        text.frame = bounds
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
    
    public func renderPlaceholder() {
        backgroundColor = .purple
    }
    
    public func render(model: Model) {
        text.text = "\(page)-\(model)"
        backgroundColor = Self.colors[page % Self.colors.count]
    }
    
    public func prepareForReuse() {
        text.text = ""
        backgroundColor = .white.withAlphaComponent(0.5)
    }
    
}
#endif
