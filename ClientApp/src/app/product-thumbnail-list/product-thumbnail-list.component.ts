import { Component, OnInit } from '@angular/core';
import { ProductThumbnail } from '../product-thumbnail';

@Component({
  selector: 'app-product-thumbnail-list',
  templateUrl: './product-thumbnail-list.component.html',
  styleUrls: ['./product-thumbnail-list.component.css']
})
export class ProductThumbnailListComponent implements OnInit {

  products: ProductThumbnail[] = [
    { code: 1234, name: 'Foo', width: 123, height: 456, small_image_url: 'small.jpg', thumbnail_url: 'thumb.jpg', image_type: 'front' },
    { code: 4321, name: 'Bar', width: 123, height: 456, small_image_url: 'small.jpg', thumbnail_url: 'thumb.jpg', image_type: 'front' }
  ];

  constructor() { }

  ngOnInit() {
  }

}
