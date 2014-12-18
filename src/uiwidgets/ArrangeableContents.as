/**
 * Created by shanemc on 9/12/14.
 */
package uiwidgets {
import com.greensock.TweenLite;
import com.greensock.easing.Linear;
import flash.display.DisplayObject;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Point;
import scratch.ScratchSprite;

import ui.dragdrop.DragAndDropMgr;
import ui.dragdrop.DropTarget;
import ui.EditableItem;
import ui.media.MediaInfo;
import ui.media.MediaInfoOnline;
import ui.dragdrop.DragEvent;
import util.GestureHandler;

public class ArrangeableContents extends ScrollFrameContents implements DropTarget {
	public static const TYPE_GRID:uint = 0;
	public static const TYPE_STRIP_HORIZONTAL:uint = 1;
	public static const TYPE_STRIP_VERTICAL:uint = 2;
	private static const leftBehindAlpha:Number = 0.6;
	private static const animationDuration:Number = 0.25;

	// Fixed state variables
	private var type:uint = 0;
	private var itemPadding:uint = 5;

	// Dynamic state variables
	private var w:uint;
	private var h:uint;
	private var selectedItem:EditableItem;
	private var editMode:Boolean;
	public function ArrangeableContents(w:uint, h:uint, t:uint = TYPE_GRID) {
		type = t;
		setWidthHeight(w, h);

		addEventListener(DragEvent.DRAG_DROP, dragAndDropHandler);
		addEventListener(DragEvent.DRAG_START, dragAndDropHandler);
		addEventListener(DragEvent.DRAG_STOP, dragAndDropHandler);
		addEventListener(DragEvent.DRAG_CANCEL, dragAndDropHandler);
		addEventListener(DragEvent.DRAG_OVER, dragAndDropHandler);
		addEventListener(DragEvent.DRAG_MOVE, dragAndDropHandler);
		addEventListener(DragEvent.DRAG_OUT, dragAndDropHandler);
		//addEventListener(MediaInfoTablet.TOUCH_LONG_HOLD, onLongHold);
	}

//	protected function onLongHold(e:Event):void {
//		setEditMode(true);
//	}

	override public function updateSize():void {
		super.updateSize();

		arrangeItems();
	}

//	private function setEditMode(enable:Boolean):void {
//		if (editMode == enable) return;
//
//		// Enter edit mode
//		editMode = enable;
//		for (var i:int=0, l:int=numChildren; i<l; ++i) {
//			var item:EditableItem = getChildAt(i) as EditableItem;
//			if (item) item.toggleEditMode(enable);
//		}
//
//		if (editMode)
//			stage.addEventListener(MouseEvent.MOUSE_DOWN, cancelEditMode);
//		else
//			stage.removeEventListener(MouseEvent.MOUSE_DOWN, cancelEditMode);
//	}

//	private function cancelEditMode(event:Event):void {
//		if (getBounds(this).contains(mouseX, mouseY)) {
//			var dObj:DisplayObject = event.target as DisplayObject;
//			while (dObj != stage && dObj != this) {
//				// If we find a MediaInfo in the target's ancestry then don't cancel edit mode
//				// since the user may be trying to drag items around
//				if (dObj is MediaInfo) return;
//				dObj = dObj.parent ? dObj.parent : stage;
//			}
//		}
//
//		setEditMode(false);
//	}

	// Move items out of the way of a dragging item
	private var dropPos:int = -1;
	private var ignoredObj:*;
	private function dragAndDropHandler(event:DragEvent):void {
		var mi:MediaInfoOnline;
		var dup:MediaInfo;
		switch(event.type) {
			case DragEvent.DRAG_START:
				event.target.visible = false;
				arrangeItems(true);
				break;

			case DragEvent.DRAG_OVER:
				mi = event.draggedObject as MediaInfoOnline;
				if (!mi) {
					var spr:ScratchSprite = event.draggedObject as ScratchSprite;
					if (spr)
						mi = Scratch.app.createMediaInfo(spr.duplicate()) as MediaInfoOnline;
				}
				if (mi) {
					dup = getItemByMD5(mi.objType, mi.md5);
					if (dup) {
						if (mi.fromBackpack) {
							dup.visible = false;
							arrangeItems(true);
						}
						else {
							// TODO: when do we ignore?
							//ignoredObj = event.draggedObject;
						}
					}
				}
			case DragEvent.DRAG_MOVE:
				if (ignoredObj == event.draggedObject) break;

				dropPos = getIndexFromPoint(event.draggedObject.localToGlobal(new Point(event.draggedObject.width/2, event.draggedObject.height/2)));
				arrangeItems(true);
				break;

			case DragEvent.DRAG_STOP:
			case DragEvent.DRAG_OUT:
				mi = event.draggedObject as MediaInfoOnline;
				if (mi && mi.fromBackpack) {
					dup = getItemByMD5(mi.objType, mi.md5);
					if (dup) {
						dup.visible = true;
						dup.alpha = event.type == DragEvent.DRAG_OUT ? leftBehindAlpha : 1;
					}
				}
				ignoredObj = null;
				dropPos = -1;
				arrangeItems(true);
				break;

			case DragEvent.DRAG_CANCEL:
				mi = event.draggedObject as MediaInfoOnline;
				if (mi) {
					dup = getItemByMD5(mi.objType, mi.md5);
					if (dup) {
						dup.visible = true;
						dup.alpha = 1;
					}
				}
				break;

			case DragEvent.DRAG_DROP: // Handled by handleDrop right now
		}
	}

	// Used for re-arranging items
	// Override for custom dropping actions
	public function handleDrop(obj:*):Boolean {
		// Accept the drop if we're re-arranging items OR we already have that item as identified by MD5
		var mi:MediaInfo = obj as MediaInfo;
		if(mi && (mi.parent == this || !!(mi = getItemByMD5(mi.objType, mi.md5)))) {
			mi.visible = true;
			if (mi.parent != this || dropPos > -1)
				addContent(mi, dropPos);
			dropPos = -1;
			arrangeItems();
			return true;
		}

		// TODO: is this correct?
		return true;
	}

	private function getItemByMD5(objType:String, md5:String):MediaInfo {
		if (!md5) return null;

		for (var i:int = 0; i < numChildren; i++) {
			var item:MediaInfo = getChildAt(i) as MediaInfo;
			if (item && item.objType == objType && item.md5 == md5) return item;
		}

		return null;
	}

	// Select an item
	private function onTap(e:Event):void {
		if (editMode || selectedItem == e.target) return;
		if (selectedItem) selectedItem.toggleSelected(false);

		selectedItem = e.target as EditableItem;
		if (selectedItem) selectedItem.toggleSelected(true);
	}

	private var contentChanged:Boolean;
	public function addContent(item:MediaInfo, where:* = null):void {
		if (where is Number && where >= 0) addChildAt(item, where as Number);
		else if (dropPos > -1) {
			var index:int = (dropPos < numChildren) ? getChildIndex(allItems()[dropPos]) : numChildren;
			addChildAt(item, index);
			dropPos = -1;
		}
		else addChild(item);

		if (item is EditableItem) (item as EditableItem).toggleEditMode(editMode);
		DragAndDropMgr.setDraggable(item, true);
		contentChanged = true;
	}

	private function getIndexFromPoint(pt:Point, forAdding:Boolean = false):int {
		var loc:Point = globalToLocal(pt);
		var i:int = 0;
		var mi:MediaInfo;
		if (type == TYPE_STRIP_HORIZONTAL) {
			for each(mi in allItems()) {
				if (mi.x + mi.width / 2 > loc.x)
					return forAdding ? getChildIndex(mi)  : i;
				++i;
			}
		}
		else if (type == TYPE_STRIP_VERTICAL) {
			for each(mi in allItems()) {
				if (mi.y + mi.height / 2 > loc.y)
					return forAdding ? getChildIndex(mi) : i;
				++i;
			}
		}
		else {
			// Grid layout
			var px:Number = loc.x - itemPadding;
			var py:Number = loc.y - itemPadding;
			var rowLen:int = w / (MediaInfo.frameWidth + itemPadding);
			var index:int = Math.max(0, Math.min(rowLen-1, Math.floor(px / (MediaInfo.frameWidth + itemPadding))) + rowLen * Math.floor(py / (MediaInfo.frameHeight + itemPadding)));
			var items:Array = allItems();
			if (items.length && index < items.length && items[index].owner != null)
				return forAdding ? getChildIndex(items[index]) : index;

			return -1;
		}

		return forAdding ? numChildren : i;
	}

	public function removeContent(which:*):void {
		if (which is MediaInfo)
			removeChild(which as MediaInfo);
		else if (which is Number)
			removeChildAt(which as Number);
		else
			throw new ArgumentError();

		contentChanged = true;
	}

	public function removeAllItems():void {
		// TODO: Fix to only remove children that are itemClass instances?
		while (numChildren > 0) removeContent(0);
	}

	override public function setWidthHeight(w:Number, h:Number):void {
		super.setWidthHeight(w, h);

		this.w = w;
		this.h = h;
		arrangeItems();
	}

	public function allItems():Array {
		var items:Array = [];
		for (var i:int = 0; i < numChildren; i++) {
			var item:MediaInfo = getChildAt(i) as MediaInfo;
			if (item && item.visible) items.push(item);
		}
		return items;
	}

	public function arrangeItems(animate:Boolean = false):void {
		if (contentChanged) {
			contentChanged = false;
			dispatchEvent(new Event(Event.CHANGE));
		}
		if (numChildren == 0) return;

		allItems().forEach(getPlacementFunc(animate));
	}

	// Return a function that places items and iterates to the next position with each call
	public function getPlacementFunc(animate:Boolean):Function {
		var nextX:int;
		var nextY:int;
		if (type == TYPE_STRIP_HORIZONTAL) {
			nextX = itemPadding * 2;
			nextY = Math.floor((h - MediaInfo.frameHeight) / 2);
			return function(item:MediaInfo, index:int, arr:Array):void {
				// Jump another position if we're on the dropPos
				if (index == dropPos) arguments.callee(null, -2, arr);
				if (item) moveItem(item, nextX, nextY, animate);
				nextX += MediaInfo.frameWidth + itemPadding;
			};
		}
		else if (type == TYPE_STRIP_VERTICAL) {
			nextX = Math.floor((w - MediaInfo.frameWidth) / 2);
			nextY = itemPadding * 2;
			return function(item:MediaInfo, index:int, arr:Array):void {
				// Jump another position if we're on the dropPos
				if (index == dropPos) arguments.callee(null, -2, arr);
				if (item) moveItem(item, nextX, nextY, animate);
				nextY += MediaInfo.frameHeight + itemPadding;
			};
		}

		nextX = itemPadding * 2;
		nextY = itemPadding * 2;
		return function(item:MediaInfo, index:int, arr:Array):void {
			// Jump another position if we're on the dropPos
			if (index == dropPos) arguments.callee(null, -2, arr);
			if (item) moveItem(item, nextX, nextY, animate);

			nextX += MediaInfo.frameWidth + itemPadding;
			if (nextX > w - MediaInfo.frameWidth) {
				nextX = itemPadding * 2;
				nextY += MediaInfo.frameHeight + itemPadding;
			}
		};
	}

	[inline]
	private function moveItem(item:MediaInfo, x:Number, y:Number, animate:Boolean = false):void {
		if (animate) {
			TweenLite.to(item, animationDuration, {
				x: x,
				y: y,
				ease: Linear
			});
		}
		else {
			item.x = x;
			item.y = y;
		}
	}
}}