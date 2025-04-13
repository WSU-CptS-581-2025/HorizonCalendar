//
//  CalendarViewUIUpdates.swift
//  HorizonCalendar
//
//  Created by main on 4/13/25.
//  Copyright © 2025 Airbnb. All rights reserved.
//

import UIKit

extension CalendarView {
    // This exists so that we can force a layout ourselves in preparation for an animated update.
    func _layoutSubviews(extendLayoutRegion: Bool) {
        scrollView.performWithoutNotifyingDelegate {
            scrollMetricsMutator.setUpInitialMetricsIfNeeded()
            scrollMetricsMutator.updateContentSizePerpendicularToScrollAxis(viewportSize: bounds.size)
        }

        let anchorLayoutItem: LayoutItem
        if let scrollToItemContext, !scrollToItemContext.animated {
            anchorLayoutItem = self.anchorLayoutItem(
                for: scrollToItemContext,
                visibleItemsProvider: visibleItemsProvider
            )
            // Clear the `scrollToItemContext` once we use it. This could happen over the course of
            // several layout pass attempts since `isReadyForLayout` might be false initially.
            self.scrollToItemContext = nil
        } else if let previousAnchorLayoutItem = self.anchorLayoutItem {
            anchorLayoutItem = previousAnchorLayoutItem
        } else {
            let initialScrollToItemContext = ScrollToItemContext(
                targetItem: .month(content.monthRange.lowerBound),
                scrollPosition: .firstFullyVisiblePosition,
                animated: false
            )
            anchorLayoutItem = self.anchorLayoutItem(
                for: initialScrollToItemContext,
                visibleItemsProvider: visibleItemsProvider
            )
        }

        let currentVisibleItemsDetails = visibleItemsProvider.detailsForVisibleItems(
            surroundingPreviouslyVisibleLayoutItem: anchorLayoutItem,
            offset: scrollView.contentOffset,
            extendLayoutRegion: extendLayoutRegion
        )
        self.anchorLayoutItem = currentVisibleItemsDetails.centermostLayoutItem

        updateVisibleViews(withVisibleItems: currentVisibleItemsDetails.visibleItems)

        visibleItemsDetails = currentVisibleItemsDetails

        let minimumScrollOffset = visibleItemsDetails?.contentStartBoundary.map {
            ($0 - firstLayoutMarginValue).alignedToPixel(forScreenWithScale: scale)
        }
        let maximumScrollOffset = visibleItemsDetails?.contentEndBoundary.map {
            ($0 + lastLayoutMarginValue).alignedToPixel(forScreenWithScale: scale)
        }
        scrollView.performWithoutNotifyingDelegate {
            scrollMetricsMutator.updateScrollBoundaries(
                minimumScrollOffset: minimumScrollOffset,
                maximumScrollOffset: maximumScrollOffset
            )
        }

        scrollView.cachedAccessibilityElements = nil
    }

    func updateVisibleViews(withVisibleItems visibleItems: Set<VisibleItem>) {
        var viewsToHideForVisibleItems = visibleViewsForVisibleItems
        visibleViewsForVisibleItems.removeAll(keepingCapacity: true)

        let contexts = reuseManager.reusedViewContexts(
            visibleItems: visibleItems,
            reuseUnusedViews: !UIAccessibility.isVoiceOverRunning
        )

        for context in contexts {
            UIView.conditionallyPerformWithoutAnimation(when: !context.isReusedViewSameAsPreviousView) {
                if context.view.superview == nil {
                    let insertionIndex = subviewInsertionIndexTracker.insertionIndex(
                        forSubviewWithCorrespondingItemType: context.visibleItem.itemType)
                    scrollView.insertSubview(context.view, at: insertionIndex)
                }

                context.view.isHidden = false

                configureView(context.view, with: context.visibleItem)
            }

            visibleViewsForVisibleItems[context.visibleItem] = context.view

            if context.isViewReused {
                // Don't hide views that were reused
                viewsToHideForVisibleItems.removeValue(forKey: context.visibleItem)
            }
        }

        // Hide any old views that weren't reused. This is faster than adding / removing subviews.
        // If VoiceOver is running, we remove the view to save memory (since views aren't reused).
        for (visibleItem, viewToHide) in viewsToHideForVisibleItems {
            if UIAccessibility.isVoiceOverRunning {
                viewToHide.removeFromSuperview()
                subviewInsertionIndexTracker.removedSubview(withCorrespondingItemType: visibleItem.itemType)
            } else {
                viewToHide.isHidden = true
            }
        }
    }

    private func configureView(_ view: ItemView, with visibleItem: VisibleItem) {
        let calendarItemModel = visibleItem.calendarItemModel
        view.calendarItemModel = calendarItemModel
        view.itemType = visibleItem.itemType
        view.frame = visibleItem.frame.alignedToPixels(forScreenWithScale: scale)

        if traitCollection.layoutDirection == .rightToLeft {
            view.transform = .init(scaleX: -1, y: 1)
        } else {
            view.transform = .identity
        }

        // Set up the selection handler
        if case let .layoutItemType(.day(day)) = visibleItem.itemType {
            view.selectionHandler = { [weak self] in
                self?.daySelectionHandler?(day)
            }
        } else {
            view.selectionHandler = nil
        }
    }
}
