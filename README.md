# StackScroller

A controlled carousel control.

# Installation

```swift
dependencies: [
    .package(url: "https://github.com/huangwenfei/StackScroller.git", .upToNextMajor(from: "0.0.1"))
]
```

```swift
import StackScroller
```

# Usage

https://github.com/user-attachments/assets/3703dbe4-0036-4f69-bf4f-339d92887337

```swift
  public private(set) lazy var stackCarousel: StackScrollView<StackColorItem> = {
      let view = StackScrollView<StackColorItem>(
          frame: .zero,
          currentPage: 0,
          count: 12, // 6,
          mode:
          .centerScale(configs: .init(
              scaleStep: 0.07,
              offsetStep: 0.25,
              isScaleOffset: false,
              baseline: .bottom,
              size: .rect(150),
              insets: .zero
          ))
      )
      view.setBeginObserver { stack in
          print(#function, #line, "Begin")
      }
      view.setEndObserver { stack in
          print(#function, #line, "End")
      }
      view.backgroundColor = .blue.withAlphaComponent(0.4)
      return view
  }()
```

`StackColorItem` : StackColorItem is only available in debug mode and is a test item.

## StackScrollContent

It is the actual content protocol for rendering.
See the `StackColorItem` implementation for details.

```swift

public protocol StackScrollContent: UIView {
    var isDisplayed: Bool { get set }
    var page: Int { get set }
    func render()
    func prepareForReuse()
}

```

## Control

```swift
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
```

The `StackScrollView` implements this protocol, and all the control methods available are here.

# Container

`StackScrollView` also has a control method `update(mode:)`, where mode corresponds to the actual implementation of the algorithm.

## Mode

```swift
public enum StackScrollViewMode: Hashable {
    case normal(configs: StackNormalViewConfiguration)
    case normalCenterScale(configs: StackNormalCenterScaleViewConfiguration)
    case centerScale(configs: StackCenterScaleViewConfiguration)
}
```

## StackNormalView

`StackNormalView` has two modes: Fill(left) and Unfill(right). A fill is an item that fills the entire parent space.

<img width="301.5" height="655.5" alt="Normal-Fill" src="https://github.com/user-attachments/assets/255a348e-c0ed-4f9c-ae6a-451fd1466ec7" />
<img width="301.5" height="655.5" alt="Normal-Unfill" src="https://github.com/user-attachments/assets/a6c9c920-d27d-45ff-bd66-4898c6624fd3" />

```swift
.normal(configs: .init(
    isFillPage: true, // false,
    size: .rect(240),
    spacing: 20,
    insets: .init(value: 10)
))
```

## StackNormalCenterScaleView

<img width="301.5" height="655.5" alt="NormalCenterScale" src="https://github.com/user-attachments/assets/abed3bc8-417d-4d50-a2be-f8ee3afd34bc" />


```swift
.normalCenterScale(configs: .init(
    scaleStep: 0.2,
    size: .rect(240),
    spacing: 10,
    insets: .zero
))
```

## StackCenterScaleView

<img width="301.5" height="655.5" alt="Stack" src="https://github.com/user-attachments/assets/3171e0ab-565b-412b-8a0d-93260e114290" />

```swift
.centerScale(configs: .init(
    scaleStep: 0.07,
    offsetStep: 0.25,
    isScaleOffset: false,
    baseline: .bottom,
    size: .rect(150),
    insets: .zero
))
```
