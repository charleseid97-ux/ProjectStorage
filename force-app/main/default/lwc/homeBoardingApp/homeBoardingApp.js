/**
 * Created by noorg on 22/09/2021.
 */
import { LightningElement, wire } from 'lwc';
import BOARD_LOGO from '@salesforce/resourceUrl/board_logo';
import getURLBoard from '@salesforce/apex/Utils.getURLBoard';
import getURLProjection from '@salesforce/apex/Utils.getURLProjection';

export default class HomeBoardingApp extends LightningElement {

        @wire(getURLBoard) urlBoard;
        @wire(getURLProjection) urlProjection;

        boardLogoUrl = BOARD_LOGO;

}