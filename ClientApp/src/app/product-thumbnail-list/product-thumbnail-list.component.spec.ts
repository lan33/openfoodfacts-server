import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { ProductThumbnailListComponent } from './product-thumbnail-list.component';

describe('ProductThumbnailListComponent', () => {
  let component: ProductThumbnailListComponent;
  let fixture: ComponentFixture<ProductThumbnailListComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ ProductThumbnailListComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(ProductThumbnailListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
