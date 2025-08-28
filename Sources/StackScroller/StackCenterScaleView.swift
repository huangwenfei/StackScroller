//
//  StackCenterScaleView.swift
//  Xiaosuimian
//
//  Created by windy on 2025/7/31.
//

import UIKit
import Yang

open class StackCenterScaleView<Content>: UIView, StackScrollViewProtocol
    where Content: StackScrollContent
{
    
    // MARK: Type
    public typealias Content = Content
    public typealias Configuration = StackCenterScaleViewConfiguration
    
    // MARK: Properties - Base
    open var oldCurrentPage: Int = 0
    open var currentPage: Int = 0 {
        didSet { oldCurrentPage = oldValue }
    }
    
    open var count: Int = 0
    open private(set) var configuration: Configuration
    
    open var pageChange: PageChangeClosure
    
    open private(set) var visiableItems: [Content] = [] // 无序
    open private(set) var reuseableItems: [Content] = [] // 无序
    
    // MARK: Properties - View
    private var loopPage: StackScrollLoopPage = .init(count: 0)
    
    private lazy var container: StackScrollViewPanContainer = {
        let view = StackScrollViewPanContainer(frame: bounds) { sender in
            self.panAction(sender: sender)
        }
        return view
    }()
    
    // MARK: Properties - Scroll
    open var beginScroll: StackBeginScrollClosure? = nil
    open var changeScroll: StackChangeScrollClosure? = nil
    open var endScroll: StackEndScrollClosure? = nil
    
    // MARK: Init
    public convenience init() {
        self.init(frame: .zero, currentPage: 0, count: 0, configuration: .init())
    }
    
    public init(
        frame: CGRect = .zero,
        currentPage: Int = 0,
        count: Int,
        configuration: Configuration,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        self.oldCurrentPage = currentPage
        self.currentPage = currentPage
        self.count = count
        self.configuration = configuration
        self.pageChange = pageChange
        super.init(frame: frame)
        commit()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func commit() {
        loopPage = .init(count: count, current: currentPage)
        addSubview(container)
    }
    
    deinit {
        pageChange = { _,_ in }
        visiableItems = []
        reuseableItems = []
    }
    
    // MARK: Layout
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        container.frame = bounds
        
        layoutElements(by: currentPage)
        rerangeElements(currentPage: currentPage)
        transformElements(currentPage: currentPage)
    }
    
    open func sideCount(count: Int) -> Int {
        Int(ceil(.init(count) * 0.5))
    }
    
    // MARK: Stack Pan Action
    @objc private func panAction(sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: container)
        
        container.contentOffset = translation
        
        switch sender.state {
        case .began:
            container.state = .start
            beginScroll?(self)
            
//            print(#function, #line, container.state)
            
        case .changed:
            let itemSize = configuration.size.size(in: container.frame.size)
            let itemWidth = itemSize.width - (configuration.insets.horizontal * 2)
            let breakWidth = configuration.breakWidth
            let breakPoint = breakWidth == nil ? itemWidth * 0.5 : breakWidth!
            
            let step = container.contentOffset.x / breakPoint
            
            container.oldRotateStep = container.rotateStep
            container.rotateStep = step > 0 ? Int(floor(abs(step))) : -Int(floor(abs(step)))
            
            let isChangeDiretion = abs(container.oldRotateStep) > abs(container.rotateStep)
            
            rotateElements(
                isChangeDiretion: isChangeDiretion,
                progress: step.progress
            )
            
            changeScroll?(self, step.progress)
            
//            print(#function, #line, step, step.progress)
            
            if container.oldRotateStep != container.rotateStep {
                container.state = .rotate
                rotateElements(isChangeDiretion: isChangeDiretion)
                changeScroll?(self, 1.0)
//                print(#function, #line, container.rotateStep, abs(container.oldRotateStep) > abs(container.rotateStep))
            } else {
                container.state = .change
//                print(#function, #line, step)
            }
            
        case .ended, .cancelled:
            resetCurrent()
            
            loopPage.clear()
            container.clear()
            
            endScroll?(self)
            
//            print(#function, #line, container.state)
            
        default:
            break
        }
        
    }
    
    private func rotateElements(isChangeDiretion: Bool, progress: CGFloat) {
        if isChangeDiretion {
            container.isRotateToNextX ? previewPage(progress) : nextPage(progress)
        } else {
            container.isRotateToNextX ? nextPage(progress) : previewPage(progress)
        }
    }
    
    private func rotateElements(isChangeDiretion: Bool) {
        if isChangeDiretion {
            container.isRotateToNextX ? previewPageDidChange() : nextPageDidChange()
        } else {
            container.isRotateToNextX ? nextPageDidChange() : previewPageDidChange()
        }
    }
    
    private func rotateTranslation(isRotateToNextX: Bool) {
        
        let oldCurrentPage = currentPage
        
        /// - Tag: Page
        isRotateToNextX ? loopPage.rotateNext() : loopPage.rotatePreview()
        self.currentPage = loopPage.current
        
        /// - Tag: Layout
        layoutElements(by: currentPage)
        
        /// - Tag: Rerange
        rerangeElements(currentPage: currentPage)
        
        /// - Tag: Transform
        transformElements(currentPage: currentPage)
        
        /// - Tag: Change
        if oldCurrentPage != currentPage {
            pageChange(oldCurrentPage, currentPage)
        }
        
    }
    
    // MARK: Layout Elements
    
    private func visiableRect(currentPage: Int) -> CGRect {
        
        let container = self.container
        let itemFrame = self.itemFrame(at: currentPage)
        
        return CGRect(
            x: itemFrame.minX - (container.frame.width - itemFrame.width) * 0.5,
            y: 0,
            width: container.frame.width,
            height: container.frame.height
        )
        
    }
    
    private func layoutElements(by currentPage: Int) {
        
//        print()
//        print("Before", #function, #line, bounds, currentPage)
        
        guard self.item(for: currentPage) != nil else {
            return
        }
        
        let visiableRect = self.visiableRect(currentPage: currentPage)
        
        clearUnvisiableItems(currentPage: currentPage, in: visiableRect)
        
        /*let edges = */sideItems(
            currentPage: currentPage,
            visiableRect: visiableRect
        )
        
//        print("......", #function, #line, currentPage, visiableRect, centerItem.frame, visiableItems.map({ ($0.page, $0.frame) }))
//        print("After", #function, #line, currentPage, edges, visiableItems.map({ $0.page }))
        
    }
    
    @discardableResult
    private func sideItems(currentPage: Int, visiableRect: CGRect) -> ClosedRange<Int> {
        
        var leftEdge: Int = 0
        var rightEdge: Int = 0
        
//        print("Loop Items", #function, #line, loopPage.current, loopPage.pages, visiableRect)
        
        loopPage.unCenterIterator { previewPage, nextPage in
            
//            print("Loop Items", #function, #line, previewPage ?? "None Preview", nextPage ?? "None Next")
            
            var isPreviewStop = false
            var isNextStop = false
            
            if
                isPreviewStop == false,
                let previewPage,
                vaildPage(previewPage)
            {
                
                let frame = itemFrame(at: previewPage)
                
//                print("Loop Items", #function, #line, "Preview", frame)
                if self.isItemContains(frame, isLeft: true, in: visiableRect) {
                    item(for: previewPage)
                    leftEdge += 1
                } else {
                    leftEdge -= 1
                    isPreviewStop = true
                }
            }
            
            if
                isNextStop == false,
                let nextPage,
                vaildPage(nextPage)
            {
                
                let frame = itemFrame(at: nextPage)
                
//                print("Loop Items", #function, #line, "Next", frame)
                if self.isItemContains(frame, isLeft: false, in: visiableRect) {
                    item(for: nextPage)
                    rightEdge += 1
                } else {
                    rightEdge -= 1
                    isNextStop = true
                }
            }
            
            return isPreviewStop && isNextStop
            
        }
        
        return min(leftEdge, rightEdge) ... max(leftEdge, rightEdge)
    }
    
    private func transformElements(currentPage: Int) {
        
        let scaleStep = configuration.scaleStep
        let offsetStep = configuration.offsetStep
        let isScaleOffset = configuration.isScaleOffset
            
        let scaleRect = self.scaleRect(
            scaleStep: scaleStep,
            offsetStep: offsetStep,
            isScaleOffset: isScaleOffset
        )
        
        visiableItems.forEach { item in
            transformElement(
                item: item,
                currentPage: currentPage,
                scaleStep: scaleStep,
                scaleRect: scaleRect
            )
        }
            
//            print(#function, #line, visiableItems.map({ ($0.page, $0.scaleStep, $0.scaleStepAnimated, $0.frame, $0.transform) }))
        
    }
    
    private func elementScale(level: Int, scaleStep: CGFloat) -> CGFloat {
        1.0 - scaleStep * .init(level)
    }
    
    private func transformElement(item: Content, currentPage: Int, scaleStep: CGFloat, scaleRect: CGRect) {
        
        let level = loopPage.level(page: item.page, current: currentPage)
        let scale = elementScale(level: level, scaleStep: scaleStep)
        item.scaleStep = scale
        let scaleStepAnimated = scaleStepAnimating(
            item: item,
            scaleStep: scaleStep,
            currentPage: currentPage,
            scaleRect: scaleRect
        )
        item.scaleStepAnimated = scaleStepAnimated
        
        item.frame = transformFrame(page: item.page, scale: scaleStepAnimated)
        item.scaleStepInitFrame = item.frame

    }
    
    private func transformFrame(page: Int, scale: CGFloat) -> CGRect {
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        
        let originFrame = itemFrame(at: page)
        let scaleFrame = originFrame.applying(scaleTransform)
        
        let translationX = abs(originFrame.width - scaleFrame.width)
        let translationY = abs(originFrame.height - scaleFrame.height)
        
        let x: CGFloat
        let y: CGFloat
        switch loopPage.location(page: page) {
        case .center:
            x = originFrame.minX
            y = originFrame.minY
            
        case .left:
            switch configuration.baseline {
            case .top:
                x = originFrame.minX
                y = originFrame.minY
                
            case .center:
                x = originFrame.minX
                y = originFrame.minY + translationY * 0.5
                
            case .bottom:
                x = originFrame.minX
                y = originFrame.minY + translationY
            }
            
        case .right:
            switch configuration.baseline {
            case .top:
                x = originFrame.minX + translationX
                y = originFrame.minY
                
            case .center:
                x = originFrame.minX + translationX
                y = originFrame.minY + translationY * 0.5
                
            case .bottom:
                x = originFrame.minX + translationX
                y = originFrame.minY + translationY
            }
        }
        
        return .init(x: x, y: y, width: scaleFrame.width, height: scaleFrame.height)
    }
    
    private func vaildScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 0), 1)
    }
    
    private func vaildScale(_ scale: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(scale, range.lowerBound), range.upperBound)
    }
    
    private func scaleRect(scaleStep: CGFloat, offsetStep: CGFloat, isScaleOffset: Bool) -> CGRect {
        let scaleRect = container.bounds
        let itemWidth = self.itemFrame(at: loopPage.current).width
        let offsetWidth = offsetStep * itemWidth
        let offsetWidths: CGFloat
        if isScaleOffset {
            var widths: CGFloat = 0
            var currentWidth = offsetWidth
            while currentWidth > 0.0001 { // 无限缩小，不会等于 0
                widths += currentWidth
                currentWidth *= scaleStep
            }
            offsetWidths = widths
        } else {
            offsetWidths = .init(loopPage.sideCount) * offsetWidth
        }
        let compressWidth = itemWidth + offsetWidths * 2
        let compressX = scaleRect.midX - compressWidth * 0.5 // - container.contentOffset.x
        return .init(x: compressX, y: scaleRect.minY, width: compressWidth, height: scaleRect.height)
    }
    
    /// `三角变化`
    ///             `1.0`
    ///              `+`
    ///           `+     +`
    ///         `+         +`
    ///       `+             +`
    ///     `+                 +`
    ///    `0.0`                             `0.0`
    ///
    private func scaleStepAnimating(item: Content, scaleStep: CGFloat, currentPage: Int, scaleRect: CGRect) -> CGFloat {
        
        let currentMidX = scaleRect.midX
        let itemMidX = item.frame.midX
        
        let offset = itemMidX - currentMidX
        let distance = scaleRect.width
        let delta = 1.0 - abs(offset / distance)
        
//        print("Animate Scale", #function, #line, item.page, offset, (delta, item.scaleStep), scaleRect)
        
        return vaildScale(delta)
        
    }
    
    private func isItemContains(_ item: Content, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        isItemContains(item.frame, isLeft: isLeft, in: visiableRect)
    }
    
    private func isItemNotContains(_ item: Content, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        isItemNotContains(item.frame, isLeft: isLeft, in: visiableRect)
    }
    
    private func isItemContains(_ item: CGRect, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        let edge = isLeft ? visiableRect.minX : visiableRect.maxX
        let isContains = isLeft ? item.minX >= edge : item.maxX <= edge
//        print("Contains", #function, #line, isLeft, edge, item)
        return isContains
    }
    
    private func isItemNotContains(_ item: CGRect, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        isItemContains(item, isLeft: isLeft, in: visiableRect) == false
    }
    
    private func clearUnvisiableItems(currentPage: Int, in visiableRect: CGRect) {
        
//        print(#function, #line, currentPage, visiableItems.map({ ($0.page, $0.frame) }))
        
        visiableItems = visiableItems.filter({ item in
            
            let frame = itemFrame(at: item.page)
            let isLeft = loopPage.isPreviewPage(preview: item.page, currentPage)
            
            guard
                isItemNotContains(frame, isLeft: isLeft, in: visiableRect)
            else {
                return true
            }
            
            itemAnimating(item, isShow: true)
            item.removeFromSuperview()
            item.resetForReuse()
            reuseableItems.append(item)
            
            return false
            
        })
        
//        print(#function, #line, currentPage, visiableItems.map({ ($0.page, $0.frame) }))
        
    }
    
    // MARK: Items
    ///
    /// `zIndex` : `0 在最顶层，min 在最底层`
    ///
    ///              `0`
    ///              `+`
    ///           `+     +`
    ///         `+         +`
    ///       `+             +`
    ///     `+                 +`
    ///    `min`             `min`
    ///
    @discardableResult
    private func item(for page: Int) -> Content? {

        guard vaildPage(page) else { return nil }
        
        if let item = visiableItems.first(where: { $0.page == page }) {
            item.frame = itemFrame(at: page)
            item.scaleStepZIndex = loopPage.zIndex(page: page)
            itemAnimatingIfNeed(item, isShow: true)
//            print("====>>", #function, #line, "visiable", page, item.frame)
            return item
        }
        else if let item = reuseableItems.popLast() {
            item.tag = page
            item.frame = itemFrame(at: page)
            item.page = page
            item.scaleStepZIndex = loopPage.zIndex(page: page)
            item.renderIfNeed()
            container.addSubview(item)
            visiableItems.append(item)
            itemAnimating(item, isShow: true)
//            print("====>>", #function, #line, "reuseable", page, item.frame, item.scaleStepZIndex)
            return item
        }
        else {
            let item = Content(frame: itemFrame(at: page))
            item.tag = page
            item.page = page
            item.scaleStepZIndex = loopPage.zIndex(page: page)
            item.renderIfNeed()
            container.addSubview(item)
            visiableItems.append(item)
            itemAnimating(item, isShow: true)
//            print("====>>", #function, #line, "create", page, item.frame, item.scaleStepZIndex)
            return item
        }
        
    }
    
    private func rerangeElements(currentPage: Int) {
        let elements = visiableItems.sorted { lhs, rhs in
            lhs.scaleStepZIndex < rhs.scaleStepZIndex
        }
        elements.forEach { item in
            container.bringSubviewToFront(item)
        }
    }
    
    private func rotatePreview(currentPage: Int) {
        guard
            let current = container.subviews.firstIndex(where: {
                guard let content = $0 as? Content else { return false }
                return content.page == currentPage
            }),
            let next = container.subviews.firstIndex(where: {
                guard let content = $0 as? Content else { return false }
                let next = loopPage.next(current: currentPage)
                return content.page == next
            })
        else {
            return
        }
        
        container.exchangeSubview(at: current, withSubviewAt: next)
    }
    
    private func rotateNext(currentPage: Int) {
        guard
            let current = container.subviews.firstIndex(where: {
                guard let content = $0 as? Content else { return false }
                return content.page == currentPage
            }),
            let preview = container.subviews.firstIndex(where: {
                guard let content = $0 as? Content else { return false }
                let preview = loopPage.preview(current: currentPage)
                return content.page == preview
            })
        else {
            return
        }
        
        container.exchangeSubview(at: current, withSubviewAt: preview)
    }
    
    private func itemAnimatingIfNeed(_ item: Content, duration: TimeInterval = 0.2, isShow: Bool, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        
        if isShow {
            if item.alpha == 1.0 { return }
        } else {
            if item.alpha == 0.0 { return }
        }
        
        itemAnimating(item, duration: duration, isShow: isShow, completion: completion)
        
    }
    
    private func itemAnimating(_ item: Content, duration: TimeInterval = 0.2, isShow: Bool, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        
        if isShow {
            item.alpha = 0
            UIView.animate(withDuration: duration) {
                item.alpha = 1
            } completion: { isFinished in
                completion?(isFinished)
            }
        } else {
            guard let snap = item.snapshotView(afterScreenUpdates: false) else {
                completion?(true)
                return
            }
            
            snap.frame = item.frame
            snap.alpha = 1
            
            let previewZIndex = loopPage.zIndex(preview: item.page)
            
            if
                let preview = visiableItems.first(
                    where: { $0.scaleStepZIndex == previewZIndex }
                )
            {
                container.insertSubview(snap, belowSubview: preview)
            } else {
                container.addSubview(snap)
            }
            
            item.isHidden = true
            
            UIView.animate(withDuration: duration) {
                snap.alpha = 0
            } completion: { isFinished in
                completion?(isFinished)
                snap.removeFromSuperview()
                item.isHidden = false
            }
            
        }
        
    }
    
    private func itemSize(at page: Int) -> CGSize {
        
        let container = self.container
        let boundSize = container.frame.size
        
        let itemSize = configuration.size.size(in: boundSize)
        
        let itemWidth = itemSize.width - (configuration.insets.horizontal * 2)
        let itemHeight = itemSize.height - (configuration.insets.vertical * 2)
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    private func itemFrame(at page: Int) -> CGRect {
        
        let container = self.container
        let boundSize = container.frame.size
        let width = boundSize.width
        let height = boundSize.height
        
        let scaleStep = configuration.scaleStep
        let offsetStep = configuration.offsetStep
        let isScaleOffset = configuration.isScaleOffset
        let size = configuration.size
        let insets = configuration.insets
            
        let level = loopPage.level(page: page)
        let itemSize = size.size(in: boundSize)
        
        let itemWidth = itemSize.width - (insets.horizontal * 2)
        let itemHeight = itemSize.height - (insets.vertical * 2)
        let y = (height - itemHeight) * 0.5
        
        let offsetWidth = offsetStep * itemWidth
        
        let totalOffsetWidths: CGFloat
        if isScaleOffset {
            var offsetWidths = CGFloat.zero
            var currentLevel = level
            while currentLevel > 0 {
                let scale = elementScale(level: currentLevel, scaleStep: scaleStep)
                offsetWidths += (scale * offsetWidth)
                currentLevel -= 1
            }
            totalOffsetWidths = offsetWidths
        } else {
            totalOffsetWidths = .init(level) * offsetWidth
        }
        
        let x: CGFloat
        switch loopPage.location(page: page) {
        case .center: x = (width - itemWidth) * 0.5
        case .left:   x = (width - itemWidth) * 0.5 - totalOffsetWidths
        case .right:  x = (width - itemWidth) * 0.5 + totalOffsetWidths
        }
        
//        print(#function, #line, page, level, offsetWidth, totalOffsetWidths, CGRect(x: x, y: y, width: itemWidth, height: itemHeight))
        
        return CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
    }
    
    // MARK: Scroll
    private func transformFrame(by page: Int) -> CGRect {
        let scaleStep = configuration.scaleStep
        let level = self.loopPage.level(page: page)
        let scale = self.elementScale(level: level, scaleStep: scaleStep)
        return self.transformFrame(page: page, scale: scale)
    }
    
    private func previewPage(_ progress: CGFloat) {
        self.visiableItems.enumerated().forEach { (index, item) in
            let currentFrame = self.transformFrame(by: item.page)
            let value = self.loopPage.next(current: item.page, isLoop: true)
            let frame = self.transformFrame(by: value)
            item.frame = currentFrame.progress(progress, target: frame)
            print(#function, #line, item.page, progress, currentFrame, frame, item.frame)
        }
    }
    
    private func nextPage(_ progress: CGFloat) {
        self.visiableItems.enumerated().forEach { (index, item) in
            let currentFrame = self.transformFrame(by: item.page)
            let value = self.loopPage.preview(current: item.page, isLoop: true)
            let frame = self.transformFrame(by: value)
            item.frame = currentFrame.progress(progress, target: frame)
            print(#function, #line, item.page, progress, currentFrame, frame, item.frame)
        }
    }
    
    private func previewPageDidChange() {
        self.visiableItems.enumerated().forEach { (index, item) in
            let value = self.loopPage.next(current: item.page, isLoop: true)
            let frame = self.transformFrame(by: value)
            item.frame = frame
        }
        _previewPage()
    }
    
    private func nextPageDidChange() {
        self.visiableItems.enumerated().forEach { (index, item) in
            let value = self.loopPage.preview(current: item.page, isLoop: true)
            let frame = self.transformFrame(by: value)
            item.frame = frame
        }
        _nextPage()
    }
    
    private func resetCurrent() {
        UIView.animate(withDuration: 0.2) {
            self.visiableItems.enumerated().forEach { (index, item) in
                item.frame = self.transformFrame(by: item.page)
            }
        } completion: { isFinished in
            guard isFinished else { return }
            self.visiableItems.enumerated().forEach { (index, item) in
                item.frame = self.transformFrame(by: item.page)
            }
        }
    }
    
    private func _previewPage() {
        self.rotateTranslation(isRotateToNextX: false)
    }
    
    private func _nextPage() {
        self.rotateTranslation(isRotateToNextX: true)
    }
    
    open func previewPage() {
        let scaleStep = configuration.scaleStep
        UIView.animate(withDuration: 0.2) {
            self.visiableItems.enumerated().forEach { (index, item) in
                let value = self.loopPage.next(current: item.page, isLoop: true)
                let level = self.loopPage.level(page: value)
                let scale = self.elementScale(level: level, scaleStep: scaleStep)
                let frame = self.transformFrame(page: value, scale: scale)
                item.frame = frame
            }
        } completion: { isFinished in
            guard isFinished else { return }
            self._previewPage()
        }
    }
    
    open func nextPage() {
        let scaleStep = configuration.scaleStep
        UIView.animate(withDuration: 0.2) {
            self.visiableItems.enumerated().forEach { (index, item) in
                let value = self.loopPage.preview(current: item.page, isLoop: true)
                let level = self.loopPage.level(page: value)
                let scale = self.elementScale(level: level, scaleStep: scaleStep)
                let frame = self.transformFrame(page: value, scale: scale)
                item.frame = frame
            }
        } completion: { isFinished in
            guard isFinished else { return }
            self._nextPage()
        }
    }
    
    open func loopPreviewPage() {
        previewPage()
    }
    
    open func loopNextPage() {
        nextPage()
    }
    
    // MARK: Update
    open func update(currentPage: Int) {
        guard
            self.currentPage != currentPage,
            (0 ..< count).contains(currentPage)
        else {
            return
        }
        
        _update(currentPage: currentPage)
    }
    
    open func update(count: Int) {
        guard count > 0, self.count != count else { return }
        
        self.count = count
        loopPage.update(count: count)
        self.currentPage = loopPage.current
        _update(currentPage: currentPage)
    }
    
    private func _update(currentPage: Int) {
        loopPage.update(current: currentPage)
        self.currentPage = loopPage.current
        layoutElements(by: self.currentPage)
        rerangeElements(currentPage: self.currentPage)
        transformElements(currentPage: self.currentPage)
    }
    
}

public struct StackCenterScaleViewConfiguration: Hashable {

    // MARK: Static
    public static let simple: Self = .init()
    
    // MARK: Properties
    public var scaleStep: CGFloat
    public var offsetStep: CGFloat
    public var isScaleOffset: Bool
    public var baseline: StackScrollViewStackScaleBaseline
    public var size: StackSctollViewSize
    public var insets: StackScrollViewInsets
    public var breakWidth: CGFloat? = nil
    
    // MARK: Init
    public init(
        scaleStep: CGFloat = 0.3,
        offsetStep: CGFloat = 0.15,
        isScaleOffset: Bool = true,
        baseline: StackScrollViewStackScaleBaseline = .bottom,
        size: StackSctollViewSize = .unspecified,
        insets: StackScrollViewInsets = .zero,
        breakWidth: CGFloat? = nil
    ) {
        self.scaleStep = scaleStep
        self.offsetStep = offsetStep
        self.isScaleOffset = isScaleOffset
        self.baseline = baseline
        self.size = size
        self.insets = insets
        self.breakWidth = breakWidth
    }
    
}

// MARK: - StackScrollLoopArray
fileprivate struct StackScrollLoopArray {
    
    // TODO: 替换 StackScrollLoopPage.pages
    
    // MARK: Properties
    var current: Int
    var leading: Int!
    var trailing: Int!
    
    var sideCount: Int
    
    // MARK: Init
    init(current: Int, sideCount: Int) {
        self.current = current
        self.sideCount = sideCount
        self.leading = calculateLeading()
        self.trailing = calculateTrailing()
    }
    
    // MARK: Calculate
    func calculateLeading() -> Int {
        fatalError()
    }
    
    func calculateTrailing() -> Int {
        fatalError()
    }
    
}

// MARK: - StackScrollLoopPage

fileprivate struct StackScrollLoopPage {
    
    /// - Tag: Properties
    
    private(set) var pages: [Int] = []
    private(set) var current: Int = 0
    
    private(set) var sideCount: Int = 0
    private(set) var count: Int = 0
    
    private var maxLevel: Int { sideCount }
    
    /// - Tag: Init
    init(count: Int, current: Int = 0) {
        let count = max(count, 0)
        let current = min(max(current, 0), max(count - 1, 0))
        self.sideCount = Int(ceil(.init(count) * 0.5))
        self.count = count
        self.current = current
        self.pages = generatePages()
    }
    
    func generatePages() -> [Int] {
        
        var pages = [Int](repeating: -1, count: count)
        
        let centerIndex = sideCount
        guard pages.indices.contains(centerIndex) else { return pages }
        pages[centerIndex] = current
        
        var currentCount = count
        
        var previewCurrentIndex = centerIndex
        var previewCurrentValue = current
        
        var nextCurrentIndex = centerIndex
        var nextCurrentValue = current
        
        while currentCount > 0 {
            
            previewCurrentIndex -= 1
            if pages.indices.contains(previewCurrentIndex) {
                previewCurrentValue = self.preview(page: previewCurrentValue)
                pages[previewCurrentIndex] = previewCurrentValue
            }
            
            nextCurrentIndex += 1
            if pages.indices.contains(nextCurrentIndex) {
                nextCurrentValue = self.next(page: nextCurrentValue)
                pages[nextCurrentIndex] = nextCurrentValue
            }
            
            currentCount -= 2
        }
        
        return pages
    }
    
    /// - Tag: Iterator
    func unCenterIterator(closure: (_ previewPage: Int?, _ nextPage: Int?) -> Bool) {
        
        let centerIndex = sideCount
        guard pages.indices.contains(centerIndex) else { return }
        
        var currentCount = count
        
        var previewCurrentIndex = centerIndex
        var previewCurrentValue: Int? = nil
        
        var nextCurrentIndex = centerIndex
        var nextCurrentValue: Int? = nil
        
        while currentCount > 0 {
            
            previewCurrentIndex -= 1
            if pages.indices.contains(previewCurrentIndex) {
                previewCurrentValue = pages[previewCurrentIndex]
            } else {
                previewCurrentValue = nil
            }
            
            nextCurrentIndex += 1
            if pages.indices.contains(nextCurrentIndex) {
                nextCurrentValue = pages[nextCurrentIndex]
            } else {
                nextCurrentValue = nil
            }
            
            let isStop = closure(previewCurrentValue, nextCurrentValue)
            
            if isStop { break }
            
            currentCount -= 2
        }
        
    }
    
    /// - Tag: Level
    // 0(current, top level), 1, 2, 3, 4 ...
    func level(page: Int) -> Int {
        level(page: page, current: current)
    }
    
    func level(page: Int, current: Int) -> Int {
        guard
            let currentIndex = pages.firstIndex(of: current),
            let pageIndex = pages.firstIndex(of: page)
        else {
            return 0
        }
        
        return abs(pageIndex - currentIndex)
    }
    
    func level(preview page: Int) -> Int {
        level(page: preview(page: page))
    }
    
    func level(next page: Int) -> Int {
        level(page: next(page: page))
    }
    
    // 3(top zIndex), 2, 1, 0
    func zIndex(page: Int) -> Int {
        sideCount - level(page: page)
    }
    
    func zIndex(preview page: Int) -> Int {
        zIndex(page: preview(page: page))
    }
    
    func zIndex(next page: Int) -> Int {
        zIndex(page: next(page: page))
    }
    
    /// - Tag: Location
    enum Location: Int {
        case center, left, right
    }
    
    func location(page: Int) -> Location {
        guard
            let currentIndex = pages.firstIndex(of: current),
            let pageIndex = pages.firstIndex(of: page)
        else {
            return .center
        }
        
        let offset = pageIndex - currentIndex
        
        if offset == 0 {
            return .center
        }
        else if offset > 0 {
            return .right
        }
        else {
            return .left
        }
    }
    
    /// - Tag: Preview & Next
    func currentPreview() -> Int {
        preview(current: current)
    }
    
    func currentNext() -> Int {
        next(current: current)
    }
    
    func preview(current: Int, isLoop: Bool = false) -> Int {
        guard let index = pages.firstIndex(of: current) else {
            return current
        }
        var preview = index - 1
        if isLoop, preview < 0 { preview = count - 1 }
        if pages.indices.contains(preview) {
            return pages[preview]
        }
        else if pages.indices.contains(count - 1) {
            return pages[count - 1]
        }
        else {
            return current
        }
    }
    
    func next(current: Int, isLoop: Bool = false) -> Int {
        guard let index = pages.firstIndex(of: current) else {
            return current
        }
        var next = index + 1
        if isLoop, next > (count - 1) { next = 0 }
        if pages.indices.contains(next) {
            return pages[next]
        }
        else if pages.indices.contains(0) {
            return pages[0]
        }
        else {
            return current
        }
    }
    
    func preview(page: Int) -> Int {
        var preview = page - 1
        if preview < 0 { preview = max(count - 1, 0) }
        return preview
    }
    
    func next(page: Int) -> Int {
        var next = page + 1
        if next > (count - 1) { next = 0 }
        return next
    }
    
    func isPreviewPage(_ current: Int) -> Bool {
        self.isPreviewPage(preview: current, self.current)
    }
    
    func isNextPage(_ current: Int) -> Bool {
        self.isNextPage(next: current, self.current)
    }
    
    func isPreviewPage(preview: Int, _ current: Int) -> Bool {
        guard
            let index = pages.firstIndex(of: preview),
            let cIndex = pages.firstIndex(of: current)
        else {
            return false
        }
        return index < cIndex
    }
    
    func isNextPage(next: Int, _ current: Int) -> Bool {
        guard
            let index = pages.firstIndex(of: next),
            let cIndex = pages.firstIndex(of: current)
        else {
            return false
        }
        return index > cIndex
    }
    
    /// - Tag: Loop Rotation
    private var oldPreviewStep = 0
    mutating func rotatePreviewIfNeed(step: Int = 1) {
        guard oldPreviewStep != step else { return }
        oldPreviewStep = step
        rotatePreview(step: step)
    }
    
    private var oldNextStep = 0
    mutating func rotateNextIfNeed(step: Int = 1) {
        guard oldNextStep != step else { return }
        oldNextStep = step
        rotateNext(step: step)
    }
    
    mutating func rotatePreview(step: Int = 1) {
//        print("Before", #function, #line, current, pages)
        var tails: [Int] = []
        var currentStep = step
        while currentStep > 0 {
            if pages.isEmpty { break }
            let tail = pages.removeLast()
            tails.append(tail)
            self.current = currentPreview()
            currentStep -= 1
        }
        pages.insert(contentsOf: tails, at: 0)
//        print("After ", #function, #line, current, pages)
    }
    
    mutating func rotateNext(step: Int = 1) {
//        print("Before", #function, #line, current, pages)
        var heads: [Int] = []
        var currentStep = 0
        while currentStep < step, pages.indices.contains(currentStep) {
            let head = pages[currentStep]
            heads.append(head)
            self.current = currentNext()
            currentStep += 1
        }
        pages.append(contentsOf: heads)
        pages.removeFirst(min(step, count))
//        print("After ", #function, #line, current, pages)
    }
    
    /// - Tag: Update
    mutating func update(current: Int) {
        self.current = min(max(current, 0), max(count - 1, 0))
        self.pages = generatePages()
    }
    
    mutating func update(count: Int) {
        let count = max(count, 0)
        self.sideCount = Int(ceil(.init(count) * 0.5))
        self.count = count
        self.update(current: current)
    }
    
    /// - Tag: Clear
    mutating func clear() {
        oldPreviewStep = 0
        oldNextStep = 0
    }
    
}

// MARK: - StackScrollTranslationState

fileprivate enum StackScrollTranslationState: Int {
    case idle, start, change, rotate
}

// MARK: - StackScrollViewPanContainer

fileprivate final class StackScrollViewPanContainer: UIView, UIGestureRecognizerDelegate {
    
    // MARK: Type
    typealias Action = (_ sender: UIPanGestureRecognizer) -> Void
    
    // MARK: Properties
    var rotateOldContentOffset: CGPoint = .zero
    var contentOffset: CGPoint = .zero
    
    var isRotateToNextX: Bool { contentOffset.x < 0 }
    var isRotateToNextY: Bool { contentOffset.y < 0 }
    
    var oldRotateStep: Int = 0
    var rotateStep: Int = 0
    
    var state: StackScrollTranslationState = .idle
    
    var panGesture: UIPanGestureRecognizer!
    var action: Action = { _ in }
    
    // MARK: Init
    init(frame: CGRect, action: @escaping Action) {
        self.action = action
        super.init(frame: frame)
        commit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commit()
    }
    
    private func commit() {
        let pan = UIPanGestureRecognizer()
        pan.addTarget(self, action: #selector(panAction(sender:)))
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        pan.delegate = self
        self.panGesture = pan
        addGestureRecognizer(pan)
    }
    
    // MARK: Action
    @objc private func panAction(sender: UIPanGestureRecognizer) {
        action(sender)
    }
    
    // MARK: Delegate
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        
        let translation = pan.translation(in: self)
        
        return translation.x != 0
    }
    
    // MARK: Clear
    func clear() {
        contentOffset = .zero
        state = .idle
        oldRotateStep = 0
        rotateStep = 0
    }
    
}

// MARK: CGPoint Extensions
fileprivate extension CGPoint {
    
    static func += (lhs: inout Self, rhs: Self) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
    
    static func -= (lhs: inout Self, rhs: Self) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
    
}

// MARK: Int
fileprivate extension Int {
    var isNegative: Bool { signum() == -1 }
    var isPositive: Bool { isNegative == false }
    
    var flag: Int { isNegative ? -1 : 1 }
}

// MARK: CGRect
fileprivate extension CGRect {
    
    struct Values {
        let current: CGFloat
        let target: CGFloat
        let lenght: CGFloat
        
        init(_ current: CGFloat, _ target: CGFloat) {
            self.init(current: current, target: target)
        }
        
        init(current: CGFloat, target: CGFloat) {
            self.current = current
            self.target = target
            self.lenght = target - current
        }
        
        func progress(_ value: CGFloat) -> CGFloat {
            current + lenght * min(max(value, 0.0), 1.0)
        }
        
    }
    
    func progress(_ progress: CGFloat, target: Self) -> Self {
        Self.progress(progress, current: self, target: target)
    }
    
    func progress(_ progress: CGFloat, current: Self) -> Self {
        Self.progress(progress, current: current, target: self)
    }
    
    static func progress(_ progress: CGFloat, current: Self, target: Self) -> Self {
        let x: Values = .init(current.minX, target.minX)
        let y: Values = .init(current.minY, target.minY)
        let w: Values = .init(current.width, target.width)
        let h: Values = .init(current.height, target.height)
        return .init(
            x: x.progress(progress),
            y: y.progress(progress),
            width: w.progress(progress),
            height: h.progress(progress)
        )
    }
}

// MARK: CGFloat

fileprivate extension CGFloat {
    
    var fract: Self {
        self - floor(self)
    }
    
    var progress: Self {
        abs(self) - floor(abs(self))
    }
    
}
