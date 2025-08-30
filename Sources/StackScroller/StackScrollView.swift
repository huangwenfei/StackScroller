//
//  StackScrollView.swift
//  Xiaosuimian
//
//  Created by windy on 2025/2/20.
//

import UIKit

// MARK: StackScrollContent
 
public protocol StackScrollContent: UIView {
    var isDisplayed: Bool { get set }
    var page: Int { get set }
    func render()
    func prepareForReuse()
}

extension StackScrollContent {
    
    internal func renderIfNeed() {
        guard isDisplayed == false else { return }
        render()
        isDisplayed = true
    }
    
    internal func resetForReuse() {
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
    var pageChange: PageChangeClosure { get set }
    
    var visiableItems: [Content] { get } // 无序
    var reuseableItems: [Content] { get } // 无序
    
}

extension StackScrollViewProtocol {
    public typealias PageChangeClosure = (_ old: Int, _ new: Int) -> Void
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


public protocol StackScrollViewFuncProtocol: UIView {
    
    func previewPage()
    func nextPage()
    func loopPreviewPage()
    func loopNextPage()
    
    func update(currentPage: Int)
    
    var beginScroll: StackBeginScrollClosure? { get set }
    var changeScroll: StackChangeScrollClosure? { get set }
    var endScroll: StackEndScrollClosure? { get set }
    
}

extension StackScrollViewFuncProtocol {
    public typealias StackBeginScrollClosure = (_ stack: any StackScrollViewProtocol) -> Void
    public typealias StackChangeScrollClosure = (_ stack: any StackScrollViewProtocol, _ progress: CGFloat) -> Void
    public typealias StackEndScrollClosure = (_ stack: any StackScrollViewProtocol) -> Void
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
    public typealias PageChangeClosure = StackScrollViewProtocol.PageChangeClosure
    
    // MARK: Properties
    open var mode: StackScrollViewMode
    open private(set) var container: (any StackScrollViewProtocol)!
    
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
    public convenience init() {
        self.init(
            frame: .zero,
            currentPage: 0,
            count: 0,
            mode: .normal(configs: .simple)
        )
    }
    
    public init(
        frame: CGRect = .zero,
        currentPage: Int = 0,
        count: Int,
        mode: StackScrollViewMode,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        self.mode = mode
        super.init(frame: frame)
        
        commit(
            mode: mode,
            currentPage: currentPage,
            count: count,
            pageChange: pageChange
        )
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commit(
        mode: StackScrollViewMode,
        currentPage: Int = 0,
        count: Int,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        createContainer(
            by: mode,
            currentPage: currentPage,
            count: count,
            pageChange: pageChange
        )
        container.yang.addToParent(self)
    }
    
    private func createContainer(
        by mode: StackScrollViewMode,
        currentPage: Int = 0,
        count: Int,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        switch mode {
        case .normal(let configs):
            container = StackNormalView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                pageChange: pageChange
            )
            
        case .normalCenterScale(let configs):
            container = StackNormalCenterScaleView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
                pageChange: pageChange
            )
            
        case .centerScale(let configs):
            container = StackCenterScaleView<Content>(
                frame: frame,
                currentPage: currentPage,
                count: count,
                configuration: configs,
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
        
        createContainer(
            by: mode,
            currentPage: container.currentPage,
            count: container.count,
            pageChange: container.pageChange
        )
        self.mode = mode
        
        container.yang.addToParent(self)
        
        setNeedsUpdateConstraints()
        setNeedsLayout()
        setNeedsDisplay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.update(currentPage: self.container.currentPage)
        }
        
    }
    
}

// MARK: - StackColorItem

#if DEBUG
public final class StackColorItem: UIView, StackScrollContent {
    
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
    
    public func render() {
        text.text = "\(page)"
        backgroundColor = Self.colors[page % Self.colors.count]
    }
    
    public func prepareForReuse() {
        text.text = ""
        backgroundColor = .white.withAlphaComponent(0.5)
    }
    
}
#endif
